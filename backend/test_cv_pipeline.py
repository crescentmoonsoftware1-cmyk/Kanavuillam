import cv2
import numpy as np
import os
import sys
import easyocr
import re
import math
from itertools import combinations
from collections import defaultdict
import json

def get_out_dir():
    out_dir = "cv_debug_output"
    os.makedirs(out_dir, exist_ok=True)
    return out_dir

def save_debug_img(filename, img):
    out_dir = get_out_dir()
    cv2.imwrite(os.path.join(out_dir, filename), img)
    print(f"Saved: {filename}")

def main(image_path):
    if not os.path.exists(image_path):
        print(f"Error: Image not found at {image_path}")
        sys.exit(1)

    print(f"Processing: {image_path}")
    original_img = cv2.imread(image_path)
    
    # A. Original image
    save_debug_img("A_original.png", original_img)

    gray = cv2.cvtColor(original_img, cv2.COLOR_BGR2GRAY)
    
    # Thresholding to extract black ink
    # Adaptive threshold is usually better for scanned images
    thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 15, 5)
    save_debug_img("A1_threshold.png", thresh)

    # B. Wall & Line Extraction
    # 1. Morphological operations to extract horizontal and vertical structures (walls)
    # This filters out most text and furniture
    horiz_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 1))
    vert_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 15))
    
    horiz_walls = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, horiz_kernel, iterations=1)
    vert_walls = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, vert_kernel, iterations=1)
    
    wall_mask = cv2.bitwise_or(horiz_walls, vert_walls)
    
    # Dilate slightly to connect small gaps
    wall_mask = cv2.dilate(wall_mask, np.ones((3,3), np.uint8), iterations=1)
    save_debug_img("B1_wall_mask.png", wall_mask)

    # Skeletonize to get single-pixel width lines for Hough
    # OpenCV doesn't have a direct skeletonize, we use a custom or approximate with thinning
    # Since ximgproc might not be available, we just use Canny on the mask
    edges = cv2.Canny(wall_mask, 50, 150)
    
    # 2. Line Detection
    min_line_length = 20
    max_line_gap = 10
    raw_lines = cv2.HoughLinesP(edges, 1, np.pi/180, threshold=30, minLineLength=min_line_length, maxLineGap=max_line_gap)
    
    if raw_lines is None:
        raw_lines = []
    else:
        raw_lines = raw_lines.reshape(-1, 4).tolist()

    print(f"Extracted {len(raw_lines)} raw line segments")
    
    # Draw raw lines
    raw_lines_img = original_img.copy()
    for x1, y1, x2, y2 in raw_lines:
        cv2.line(raw_lines_img, (x1, y1), (x2, y2), (0, 0, 255), 2)
    save_debug_img("B2_raw_lines.png", raw_lines_img)

    # 3. Line Merging (Merge collinear lines across doors/windows)
    def merge_lines(lines, dist_thresh=90, angle_thresh=5):
        if not len(lines): return []
        
        # Helper to get line properties
        def line_props(l):
            x1, y1, x2, y2 = l
            dx = x2 - x1
            dy = y2 - y1
            length = math.hypot(dx, dy)
            angle = math.degrees(math.atan2(dy, dx)) % 180
            if angle > 90: angle -= 180
            return length, angle
        
        horiz = []
        vert = []
        
        for l in lines:
            length, angle = line_props(l)
            if length < 10: continue
            if abs(angle) < angle_thresh:  # Horizontal
                # Ensure x1 < x2
                if l[0] > l[2]: l = [l[2], l[3], l[0], l[1]]
                horiz.append(l)
            elif abs(abs(angle) - 90) < angle_thresh:  # Vertical
                # Ensure y1 < y2
                if l[1] > l[3]: l = [l[2], l[3], l[0], l[1]]
                vert.append(l)
                
        def merge_group(group, is_horiz):
            if not group: return []
            # Sort by orthogonal coordinate (y for horiz, x for vert)
            idx = 1 if is_horiz else 0
            group.sort(key=lambda l: l[idx])
            
            merged = []
            current_band = [group[0]]
            
            for i in range(1, len(group)):
                l = group[i]
                # If close in orthogonal direction
                if abs(l[idx] - current_band[0][idx]) < 15:
                    current_band.append(l)
                else:
                    merged.extend(merge_collinear_band(current_band, is_horiz))
                    current_band = [l]
            merged.extend(merge_collinear_band(current_band, is_horiz))
            return merged
            
        def merge_collinear_band(band, is_horiz):
            # Sort by parallel coordinate (x for horiz, y for vert)
            p_idx = 0 if is_horiz else 1
            band.sort(key=lambda l: l[p_idx])
            
            res = []
            cur = band[0]
            for i in range(1, len(band)):
                l = band[i]
                # Check overlap or small gap
                gap = l[p_idx] - cur[p_idx+2]
                if gap < dist_thresh:
                    # Merge: cur ends at max of cur end and l end
                    cur[p_idx+2] = max(cur[p_idx+2], l[p_idx+2])
                    # Average the orthogonal coordinate
                    o_idx = 1 if is_horiz else 0
                    cur[o_idx] = int((cur[o_idx] + l[o_idx]) / 2)
                    cur[o_idx+2] = cur[o_idx]
                else:
                    res.append(cur)
                    cur = l
            res.append(cur)
            return res
            
        final_horiz = merge_group(horiz, True)
        final_vert = merge_group(vert, False)
        return final_horiz + final_vert

    merged_lines = merge_lines(raw_lines)
    
    merged_lines_img = original_img.copy()
    for x1, y1, x2, y2 in merged_lines:
        cv2.line(merged_lines_img, (x1, y1), (x2, y2), (0, 255, 0), 3)
    save_debug_img("B3_merged_lines.png", merged_lines_img)
    
    # 4. Wall Graph Construction
    nodes = set()
    
    # Extract nodes from intersections
    horiz_lines = [l for l in merged_lines if abs(l[1] - l[3]) < abs(l[0] - l[2])]
    vert_lines = [l for l in merged_lines if abs(l[0] - l[2]) <= abs(l[1] - l[3])]
    
    margin = 30
    candidate_bridges = []
    
    for h in horiz_lines:
        for v in vert_lines:
            ix, iy = v[0], h[1]
            hx_min, hx_max = min(h[0], h[2]), max(h[0], h[2])
            vy_min, vy_max = min(v[1], v[3]), max(v[1], v[3])
            
            dist_x = max(0, hx_min - ix, ix - hx_max)
            dist_y = max(0, vy_min - iy, iy - vy_max)
            
            # Check if intersection is within the extended bounding box of both lines
            if dist_x <= margin and dist_y <= margin:
                nodes.add((ix, iy))
            else:
                # Context-Aware Gap Bridging (30 to 130 pixels)
                if 30 <= dist_x <= 130 and dist_y <= margin:
                    p1 = (ix, iy)
                    p2 = (hx_min if ix < hx_min else hx_max, iy)
                    candidate_bridges.append((p1, p2))
                if 30 <= dist_y <= 130 and dist_x <= margin:
                    p1 = (ix, iy)
                    p2 = (ix, vy_min if iy < vy_min else vy_max)
                    candidate_bridges.append((p1, p2))
                if 30 <= dist_x <= 130 and 30 <= dist_y <= 130:
                    candidate_bridges.append(((ix, iy), (hx_min if ix < hx_min else hx_max, iy)))
                    candidate_bridges.append(((ix, iy), (ix, vy_min if iy < vy_min else vy_max)))
                
    # Also add endpoints of lines if they are not close to an intersection
    for l in merged_lines:
        nodes.add((l[0], l[1]))
        nodes.add((l[2], l[3]))
        
    nodes = list(nodes)
    
    # Merge nodes that are very close to each other
    merged_nodes = []
    for n in nodes:
        if not merged_nodes:
            merged_nodes.append(n)
        else:
            closest = min(merged_nodes, key=lambda mn: math.hypot(mn[0]-n[0], mn[1]-n[1]))
            if math.hypot(closest[0]-n[0], closest[1]-n[1]) > 15:
                merged_nodes.append(n)
    nodes = merged_nodes

    edges = set()
    # Associate nodes with lines to create edges
    for l in merged_lines:
        line_nodes = []
        is_horiz = abs(l[1] - l[3]) < abs(l[0] - l[2])
        for n in nodes:
            # Check if node lies on the line (extended by margin)
            if is_horiz:
                if abs(n[1] - l[1]) < 15 and min(l[0], l[2]) - margin <= n[0] <= max(l[0], l[2]) + margin:
                    line_nodes.append(n)
            else:
                if abs(n[0] - l[0]) < 15 and min(l[1], l[3]) - margin <= n[1] <= max(l[1], l[3]) + margin:
                    line_nodes.append(n)
                    
        # Sort nodes along the line
        line_nodes.sort(key=lambda n: n[0] if is_horiz else n[1])
        
        # Create edges between adjacent nodes on the line
        for i in range(len(line_nodes) - 1):
            n1 = line_nodes[i]
            n2 = line_nodes[i+1]
            if math.hypot(n1[0]-n2[0], n1[1]-n2[1]) > 5:  # Ignore degenerate edges
                edge = tuple(sorted([n1, n2]))
                edges.add(edge)
                
    # Evaluate and insert candidate bridges
    def lines_intersect(p1, p2, p3, p4):
        def ccw(A, B, C):
            return (C[1]-A[1]) * (B[0]-A[0]) > (B[1]-A[1]) * (C[0]-A[0])
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) and ccw(p1, p2, p3) != ccw(p1, p2, p4)

    accepted_bridges = []
    rejected_bridges = []
    door_edges = set()
    
    for bridge in candidate_bridges:
        p1, p2 = bridge
        crosses = False
        for l in merged_lines:
            shrink = 2
            l_p1, l_p2 = (l[0], l[1]), (l[2], l[3])
            if l[0] == l[2]: # vertical
                if abs(l[1]-l[3]) <= shrink*2: continue
                l_p1 = (l[0], min(l[1], l[3]) + shrink)
                l_p2 = (l[0], max(l[1], l[3]) - shrink)
            else:
                if abs(l[0]-l[2]) <= shrink*2: continue
                l_p1 = (min(l[0], l[2]) + shrink, l[1])
                l_p2 = (max(l[0], l[2]) - shrink, l[1])
            
            if lines_intersect(p1, p2, l_p1, l_p2):
                crosses = True
                break
                
        if crosses:
            rejected_bridges.append({"bridge": bridge, "reason": "Crosses existing wall"})
        else:
            accepted_bridges.append(bridge)
            # Add to nodes and edges
            nodes.append(p1)
            nodes.append(p2)
            edge = tuple(sorted([p1, p2]))
            door_edges.add(edge)
            edges.add(edge)

    print(f"Constructed Wall Graph: {len(nodes)} nodes, {len(edges)} edges")
    print(f"Bridges: {len(candidate_bridges)} candidates, {len(accepted_bridges)} accepted, {len(rejected_bridges)} rejected")

    graph_img = original_img.copy()
    for e in edges:
        n1, n2 = e
        color = (0, 165, 255) if e in door_edges else (255, 0, 0)
        cv2.line(graph_img, n1, n2, color, 3)
    for n in nodes:
        cv2.circle(graph_img, n, 4, (0, 255, 255), -1)
    
    # 5. Room Polygon Derivation
    # To find minimal cycles (faces) in our planar graph, we can draw the graph
    # and extract contours of the empty spaces.
    
    # Draw graph edges on a blank mask
    h, w = original_img.shape[:2]
    graph_mask = np.zeros((h, w), dtype=np.uint8)
    for n1, n2 in edges:
        cv2.line(graph_mask, n1, n2, 255, 2)
        
    # Invert so rooms are white, walls are black
    rooms_mask = cv2.bitwise_not(graph_mask)
    
    # Find contours
    contours, hierarchy = cv2.findContours(rooms_mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    
    room_polygons = []
    for i, cnt in enumerate(contours):
        # In RETR_CCOMP, hierarchy[0][i][3] is the parent. We only want internal holes (which are the rooms in our inverted mask)
        # Actually, since walls are black and rooms are white, the rooms are the foreground components!
        # So we just want components that do NOT touch the image border!
        x, y, w_cnt, h_cnt = cv2.boundingRect(cnt)
        if x <= 5 or y <= 5 or (x + w_cnt) >= (w - 5) or (y + h_cnt) >= (h - 5):
            continue # Skip exterior
            
        area = cv2.contourArea(cnt)
        # Filter out tiny noise (e.g. wall thickness gaps < ~10 sq ft)
        # Assuming ~30px/ft, 10 sq ft = 10 * 30 * 30 = 9000 px. Let's use 5000 as threshold
        if area > 3000:
            # Approximate the polygon strictly to get corners
            epsilon = 0.01 * cv2.arcLength(cnt, True)
            approx = cv2.approxPolyDP(cnt, epsilon, True)
            if len(approx) >= 4:
                room_polygons.append(approx)
                
    print(f"Extracted {len(room_polygons)} room polygons from Graph")
    
    poly_img = original_img.copy()
    for i, poly in enumerate(room_polygons):
        color = ((i * 50) % 255, (i * 100) % 255, (i * 150 + 100) % 255)
        cv2.drawContours(poly_img, [poly], -1, color, -1)
        # alpha blend
    poly_img = cv2.addWeighted(original_img, 0.4, poly_img, 0.6, 0)
    save_debug_img("D_room_polygons.png", poly_img)
    
    # 6. Semantic & Feature Extraction (OCR)
    ARCH_VOCAB = {
        "Master Bedroom": ["master bed", "master bedroom", "m.bed", "m bed", "bed room 1", "bedroom 1", "master"],
        "Bedroom": ["bedroom", "bed room", "bed", "hedroom", "guest bed", "kids bed", "bed 2", "bed 3", "children bed", "guest room"],
        "Living": ["living room", "living", "hall", "drawing room", "drawing", "sitout", "lounge", "family room"],
        "Dining": ["dining", "dining room", "dining hall", "dine", "dinning"],
        "Kitchen": ["kitchen", "modular kitchen", "open kitchen", "cook", "kit", "kitchenette", "wet kitchen"],
        "Puja": ["puja", "pooja", "mandir", "prayer room", "prayer", "pooja room", "puja room"],
        "Toilet": ["toilet", "bath", "bathroom", "wc", "attached toilet", "common toilet", "powder room"],
        "Staircase": ["staircase", "stairs", "stair", "steps", "dn", "up", "step"],
        "Balcony": ["balcony", "open balcony", "terrace", "open terrace", "deck", "verandah", "veranda", "patio"],
        "Portico": ["portico", "car parking", "parking", "porch", "car porch", "garage", "driveway", "main gate", "gate"],
        "Lobby": ["lobby", "passage", "corridor", "hallway", "foyer", "entry foyer"],
        "Utility": ["utility", "wash area", "wash", "store", "store room", "pantry", "work area"]
    }

    def normalize_label(text):
        t_clean = re.sub(r'[^a-z0-9 ]', '', text.lower().strip()).replace(' ', '')
        for standard_name, keywords in ARCH_VOCAB.items():
            if any(k.replace(' ', '') in t_clean for k in keywords):
                return standard_name
        return None

    reader = easyocr.Reader(['en'], gpu=False, verbose=False)
    results = reader.readtext(image_path, mag_ratio=3.0)
    
    room_labels = []
    dimensions = []

    for bbox, text, prob in results:
        if prob < 0.1: continue
        tl, tr, br, bl = bbox
        cx = (tl[0] + br[0]) / 2.0
        cy = (tl[1] + br[1]) / 2.0
        
        t_clean = text.strip()
        
        # Check if text is a dimension like 12'x14' or 12x14
        m = re.search(r'(\d+(?:\.\d+)?)(?:\'|ft)?(?:\d+\")?x(\d+(?:\.\d+)?)(?:\'|ft)?(?:\d+\")?', t_clean.lower().replace(' ', ''))
        if m:
            dimensions.append({
                "w": float(m.group(1)),
                "h": float(m.group(2)),
                "cx": float(cx), "cy": float(cy), 
                "bbox": [[float(pt[0]), float(pt[1])] for pt in bbox]
            })
            continue
            
        norm = normalize_label(t_clean)
        if norm:
            room_labels.append({
                "label": norm,
                "cx": cx, "cy": cy, "bbox": bbox
            })

    # Point in Polygon Mapping
    mapped_rooms = []
    ocr_img = original_img.copy()
    
    for poly in room_polygons:
        # Find which label is inside this polygon
        assigned_label = None
        for r_label in room_labels:
            if cv2.pointPolygonTest(poly, (r_label['cx'], r_label['cy']), False) >= 0:
                assigned_label = r_label['label']
                cv2.putText(ocr_img, assigned_label, (int(r_label['cx'])-40, int(r_label['cy'])), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
                break
                
        # Find which dimensions belong to this polygon
        assigned_dims = []
        for dim in dimensions:
            if cv2.pointPolygonTest(poly, (dim['cx'], dim['cy']), False) >= 0:
                assigned_dims.append(dim)
                cv2.putText(ocr_img, f"{dim['w']}x{dim['h']}", (int(dim['cx'])-30, int(dim['cy'])+20), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 2)
                
        # Calculate polygon bounding box for JSON
        x, y, w, h = cv2.boundingRect(poly)
        
        mapped_rooms.append({
            "label": assigned_label or "Unknown",
            "polygon_pts": [[float(pt[0][0]), float(pt[0][1])] for pt in poly],
            "dimensions": assigned_dims,
            "bounds": {"x": float(x), "y": float(y), "w": float(w), "h": float(h)}
        })
        
    save_debug_img("E_ocr_mapping.png", ocr_img)
    
    # 7. Scale Calibration
    ratios = []
    
    for r in mapped_rooms:
        if r['dimensions']:
            dim = r['dimensions'][0]
            ft_w = dim['w']
            ft_h = dim['h']
            px_w = r['bounds']['w']
            px_h = r['bounds']['h']
            
            # Check normal orientation
            ratio1_w = px_w / ft_w if ft_w > 0 else 0
            ratio1_h = px_h / ft_h if ft_h > 0 else 0
            
            # Check swapped orientation
            ratio2_w = px_w / ft_h if ft_h > 0 else 0
            ratio2_h = px_h / ft_w if ft_w > 0 else 0
            
            diff1 = abs(ratio1_w - ratio1_h)
            diff2 = abs(ratio2_w - ratio2_h)
            
            if diff1 < diff2:
                if ratio1_w > 0: ratios.append(ratio1_w)
                if ratio1_h > 0: ratios.append(ratio1_h)
            else:
                if ratio2_w > 0: ratios.append(ratio2_w)
                if ratio2_h > 0: ratios.append(ratio2_h)
                
    if ratios:
        ratios.sort()
        global_scale = ratios[len(ratios)//2] # Median
    else:
        global_scale = 30.0 # Fallback 30 pixels per foot

    print(f"Calibrated Global Scale: {global_scale:.2f} pixels per foot")

    solid_edges = edges - door_edges
    
    canonical_json = {
        "metadata": {
            "scale_px_per_ft": global_scale
        },
        "rooms": [
            {
                "label": r['label'],
                "polygon": [[round(pt[0]/global_scale, 2), round(pt[1]/global_scale, 2)] for pt in r['polygon_pts']]
            }
            for r in mapped_rooms
        ],
        "walls": [
            {
                "start": [round(n1[0]/global_scale, 2), round(n1[1]/global_scale, 2)],
                "end": [round(n2[0]/global_scale, 2), round(n2[1]/global_scale, 2)],
                "thickness": 0.5
            }
            for n1, n2 in solid_edges
        ],
        "openings": [
            {
                "start": [round(n1[0]/global_scale, 2), round(n1[1]/global_scale, 2)],
                "end": [round(n2[0]/global_scale, 2), round(n2[1]/global_scale, 2)],
                "type": "door_or_window"
            }
            for n1, n2 in door_edges
        ]
    }
        
    with open(os.path.join(get_out_dir(), "canonical_output.json"), "w") as f:
        json.dump(canonical_json, f, indent=2)
        
    # 9. 2D Reconstruction Visualization
    recon_img = np.zeros((h, w, 3), dtype=np.uint8)
    # Draw walls in white
    for w_obj in canonical_json["walls"]:
        pt1 = (int(w_obj['start'][0] * global_scale), int(w_obj['start'][1] * global_scale))
        pt2 = (int(w_obj['end'][0] * global_scale), int(w_obj['end'][1] * global_scale))
        cv2.line(recon_img, pt1, pt2, (255, 255, 255), 4)
        
    # Draw rooms
    for r_obj in canonical_json["rooms"]:
        pts = np.array([[int(pt[0]*global_scale), int(pt[1]*global_scale)] for pt in r_obj['polygon']], np.int32)
        cv2.polylines(recon_img, [pts], True, (0, 255, 0), 2)
        
        M = cv2.moments(pts)
        if M["m00"] != 0:
            cx = int(M["m10"] / M["m00"])
            cy = int(M["m01"] / M["m00"])
            cv2.putText(recon_img, r_obj['label'], (cx-30, cy), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1)

    save_debug_img("G_reconstruction.png", recon_img)
    
    # 10. Validation Overlay
    # Overlay the original plan + reconstructed plan
    overlay_img = original_img.copy()
    
    # Draw canonical walls in neon cyan on top of the original image
    for w_obj in canonical_json["walls"]:
        pt1 = (int(w_obj['start'][0] * global_scale), int(w_obj['start'][1] * global_scale))
        pt2 = (int(w_obj['end'][0] * global_scale), int(w_obj['end'][1] * global_scale))
        cv2.line(overlay_img, pt1, pt2, (255, 255, 0), 4) # Cyan for walls
        
    # Draw rooms in magenta
    for r_obj in canonical_json["rooms"]:
        pts = np.array([[int(pt[0]*global_scale), int(pt[1]*global_scale)] for pt in r_obj['polygon']], np.int32)
        cv2.polylines(overlay_img, [pts], True, (255, 0, 255), 2)
        
        M = cv2.moments(pts)
        if M["m00"] != 0:
            cx = int(M["m10"] / M["m00"])
            cy = int(M["m01"] / M["m00"])
            cv2.putText(overlay_img, r_obj['label'], (cx-40, cy), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

    save_debug_img("H_overlay_validation.png", overlay_img)
    
    # Also log scale calculation details to a JSON for the validation report
    room_logs = []
    for r in mapped_rooms:
        area = cv2.contourArea(np.array(r['polygon_pts'], dtype=np.float32))
        cx = r['bounds']['x'] + r['bounds']['w'] / 2.0
        cy = r['bounds']['y'] + r['bounds']['h'] / 2.0
        room_logs.append({
            "label": r['label'],
            "area_sq_px": float(area),
            "area_sq_ft": float(area / (global_scale * global_scale)),
            "centroid_px": [float(cx), float(cy)],
            "dimensions_detected": r['dimensions']
        })

    validation_data = {
        "rooms_detected": len(mapped_rooms),
        "walls_detected": len(edges),
        "scale_ratios": ratios,
        "final_scale": global_scale,
        "rooms": room_logs
    }
    with open(os.path.join(get_out_dir(), "validation_metrics.json"), "w") as f:
        json.dump(validation_data, f, indent=2)

    print("Milestone 1 Pipeline Execution Complete.")

if __name__ == "__main__":
    # Test file defaults to the specific image provided by user if no arg passed
    default_test_image = r"g:\mobile app\ai house\backend\uploads\1789447220012.png"
    target_img = sys.argv[1] if len(sys.argv) > 1 else default_test_image
    main(target_img)
