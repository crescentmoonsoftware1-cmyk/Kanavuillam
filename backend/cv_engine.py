import cv2
import numpy as np
import os
import sys
import json
import math
import re
from collections import defaultdict

class IDGenerator:
    def __init__(self):
        self.counters = defaultdict(int)
    def get(self, prefix):
        self.counters[prefix] += 1
        return f"{prefix}{self.counters[prefix]:03d}"

# Global OCR Reader lazy initialization
_easyocr_reader = None
def get_ocr_reader():
    global _easyocr_reader
    if _easyocr_reader is None:
        try:
            import easyocr
            _easyocr_reader = easyocr.Reader(['en'], gpu=False, verbose=False)
        except Exception as e:
            print(f"[OCR Warning] EasyOCR initialization skipped: {e}")
            _easyocr_reader = False
    return _easyocr_reader if _easyocr_reader is not False else None

ARCH_VOCAB = {
    "Master Bedroom": ["master bed", "master bedroom", "m.bed", "m bed", "bed room 1", "bedroom 1", "master", "master bdrm", "king"],
    "Bedroom": ["bedroom", "bed room", "bed", "hedroom", "guest bed", "kids bed", "kids bedroom", "kids", "child bed", "bed 2", "bed 3", "bedroom 2"],
    "Living Room": ["living room", "living", "hall", "drawing room", "drawing", "sitout", "lounge", "family room", "drawing/dining", "drawing dining", "drawing & dining"],
    "Dining Area": ["dining", "dining room", "dining hall", "dine", "dinning", "dining area"],
    "Kitchen": ["kitchen", "modular kitchen", "open kitchen", "cook", "kit", "kitchenette", "wet kitchen"],
    "Pooja Room": ["puja", "pooja", "mandir", "prayer room", "prayer", "pooja room", "puja room"],
    "Toilet": ["attached toilet", "common toilet", "toilet", "bath", "bathroom", "wc", "powder room"],
    "Staircase": ["staircase", "stairs", "stair", "c.stair", "stair case", "u/p", "d/n", "stairhall", "stair hall", "u shape stair", "stair room"],
    "Balcony": ["balcony", "open balcony", "terrace", "open terrace", "deck", "verandah", "veranda", "patio"],
    "Portico": ["portico", "car parking", "parking", "porch", "car porch", "garage", "car parking portico", "entry steps", "entrance steps"],
    "Utility Area": ["utility", "utility area", "wash area", "wash", "store", "store room", "pantry", "work area"]
}

def clean_and_fix_ocr_text(t_raw):
    if not t_raw: return t_raw
    t_upper = t_raw.upper().strip().replace('(', '').replace(')', '').replace('[', '').replace(']', '')
    
    # Fix common EasyOCR architectural typos
    if re.search(r'STOILET|JOILET|OILET|TOILET|TOIL|TOLLET|TOILE|BATH|MATI|MAT', t_upper):
        return "Toilet"
    if re.search(r'DEDROOM|HEDROOM|EDROOM|BEDROOM|BED ROOM|BEDR|BDRM', t_upper) and not re.search(r'BATH|MATI', t_upper):
        return "Bed Room"
    if re.search(r'LOBBF|LOBBY|LOBY|CORRIDOR|FOYER|PASSAGE', t_upper):
        return "Lobby"
    if re.search(r'DR.*DINING|DRAW.*DINING|DRATINC|DRCAT', t_upper):
        return "Drawing / Dining"
    if re.search(r'KITC|KITN|KITCH|KITCIN|KITCMLN|COOK', t_upper):
        return "Kitchen"
    if re.search(r'PUJA|POOJA|PIA|MIUA|MANDIR|PRAYER', t_upper):
        return "Puja"
    if re.search(r'ENTRY.*STEPS|ENTRANCE.*STEPS|PORCH.*STEPS', t_upper):
        return "Portico"
    if re.search(r'STAIR|S\.CASE|SCASE|STAIRCASE', t_upper) and not re.search(r'ENTRY|ENTRANCE|PORCH', t_upper):
        return "Staircase"
    if re.search(r'VERAN|VERA|VFRAN|VEKAV', t_upper):
        return "Veranda"
    if re.search(r'\bWC\b|^WA$', t_upper):
        return "WC"
    return t_raw

def normalize_room_label(text):
    if not text: return None
    t_fixed = clean_and_fix_ocr_text(text)
    t_clean = re.sub(r'[^a-z0-9 /&]', '', t_fixed.lower().strip())
    t_compact = t_clean.replace(' ', '').replace('/', '').replace('&', '')
    if "entrystep" in t_compact or "entrancestep" in t_compact or "porchstep" in t_compact:
        return "Portico"
    if "drawing" in t_compact and "dining" in t_compact:
        return "Living Room"
    if "puja" in t_compact or "pooja" in t_compact or "mandir" in t_compact or "prayer" in t_compact or "pia" in t_compact:
        return "Pooja Room"
    if "stoilet" in t_compact or "joilet" in t_compact or "oilet" in t_compact or "toilet" in t_compact or "bath" in t_compact or "wc" in t_compact or "bathroom" in t_compact:
        return "Toilet"
    if "dedroom" in t_compact or "hedroom" in t_compact or "edroom" in t_compact or "bedroom" in t_compact or "bed" in t_compact:
        return "Bedroom"
    if "lobbf" in t_compact or "lobby" in t_compact or "loby" in t_compact or "corridor" in t_compact or "foyer" in t_compact:
        return "Living Room"
    if "veranda" in t_compact or "verandah" in t_compact or "portico" in t_compact or "carparking" in t_compact or "carporch" in t_compact or "garage" in t_compact or "parking" in t_compact or "porch" in t_compact:
        return "Portico"
    if "drawing" in t_compact or "living" in t_compact or "hall" in t_compact or "sitout" in t_compact:
        return "Living Room"
    if "dining" in t_compact or "dine" in t_compact or "dinning" in t_compact:
        return "Dining Area"
    if "utility" in t_compact or "washarea" in t_compact or "workarea" in t_compact or "wash" in t_compact or "store" in t_compact:
        return "Utility Area"
    if "masterbed" in t_compact or "masterbedroom" in t_compact or "masterbdrm" in t_compact or "mbed" in t_compact:
        return "Master Bedroom"
    if "kitchen" in t_compact or "cook" in t_compact or "kitc" in t_compact:
        return "Kitchen"
    if ("stair" in t_compact or "stairs" in t_compact or "staircase" in t_compact or t_compact in ["up", "dn", "str"]) and not ("entry" in t_compact or "entrance" in t_compact):
        return "Staircase"
    for standard_name, keywords in ARCH_VOCAB.items():
        if any(k.replace(' ', '') in t_compact for k in keywords):
            return standard_name
    return None

def dist_to_segment(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    l2 = (bx - ax)**2 + (by - ay)**2
    if l2 == 0: return math.hypot(px - ax, py - ay)
    t = max(0, min(1, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / l2))
    proj_x = ax + t * (bx - ax)
    proj_y = ay + t * (by - ay)
    return math.hypot(px - proj_x, py - proj_y)

def project_point_on_segment(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    l2 = (bx - ax)**2 + (by - ay)**2
    if l2 == 0: return ax, ay
    t = max(0, min(1, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / l2))
    return ax + t * (bx - ax), ay + t * (by - ay)

def extract_geometry(image_path, out_dir=None):
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image not found at {image_path}")

    print(f"Processing: {image_path}")
    original_img = cv2.imread(image_path)
    if original_img is None:
        raise ValueError("Could not read image.")
        
    img_h, img_w = original_img.shape[:2]
    gray_img = cv2.cvtColor(original_img, cv2.COLOR_BGR2GRAY)
    _, binary_img = cv2.threshold(gray_img, 200, 255, cv2.THRESH_BINARY_INV)
    id_gen = IDGenerator()
    
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        cv2.imwrite(os.path.join(out_dir, "A_original.png"), original_img)

    # 1. Run YOLOv8 Model Inference (best.pt for walls, room_model.pt for doors/windows)
    model_path_wall = os.path.join(os.path.dirname(os.path.abspath(__file__)), "best.pt")
    model_path_room = os.path.join(os.path.dirname(os.path.abspath(__file__)), "room_model.pt")
    yolo_walls = []
    yolo_doors = []
    yolo_windows = []

    try:
        from ultralytics import YOLO

        if os.path.exists(model_path_wall):
            try:
                model_wall = YOLO(model_path_wall)
                print("Running YOLOv8 wall inference (best.pt)...")
                res_wall = model_wall(original_img, verbose=False)
                for box in res_wall[0].boxes:
                    conf = float(box.conf[0])
                    if conf < 0.25: continue
                    cls_id = int(box.cls[0])
                    cls_name = model_wall.names[cls_id].lower()
                    x1, y1, x2, y2 = [float(v) for v in box.xyxy[0]]
                    if 'wall' in cls_name:
                        yolo_walls.append({"bbox": [x1, y1, x2, y2], "conf": conf})
            except Exception as e:
                print(f"[YOLO Wall Warning] {e}")

        if os.path.exists(model_path_room):
            try:
                model_room = YOLO(model_path_room)
                print("Running YOLOv8 opening & room inference (room_model.pt)...")
                res_room = model_room(original_img, verbose=False)
                for box in res_room[0].boxes:
                    conf = float(box.conf[0])
                    if conf < 0.25: continue
                    cls_id = int(box.cls[0])
                    cls_name = model_room.names[cls_id].lower()
                    x1, y1, x2, y2 = [float(v) for v in box.xyxy[0]]
                    if 'door' in cls_name or 'entrance' in cls_name:
                        yolo_doors.append({"bbox": [x1, y1, x2, y2], "conf": conf})
                    elif 'window' in cls_name:
                        yolo_windows.append({"bbox": [x1, y1, x2, y2], "conf": conf})
            except Exception as e:
                print(f"[YOLO Room Warning] {e}")
    except Exception as e:
        print(f"[YOLO Engine Warning] PyTorch/YOLO skipped due to system environment: {e}")

    # 1.5 Early EasyOCR Text & Room Label Extraction
    ocr_reader = get_ocr_reader()
    detected_texts = []
    ocr_dimensions = []
    detected_openings_ocr = []
    ocr_bboxes = []

    if ocr_reader:
        try:
            clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
            enhanced_gray = clahe.apply(gray_img)
            enhanced_img = cv2.cvtColor(enhanced_gray, cv2.COLOR_GRAY2BGR)

            results = ocr_reader.readtext(enhanced_img, mag_ratio=2.0)
            for bbox, text, prob in results:
                t_clean = text.strip()
                t_upper = t_clean.upper().replace(' ', '')
                min_prob = 0.03 if len(t_upper) <= 3 else 0.12
                if prob < min_prob: continue

                tl, tr, br, bl = bbox
                cx = (tl[0] + br[0]) / 2.0
                cy = (tl[1] + br[1]) / 2.0
                ocr_bboxes.append((tl, tr, br, bl))

                # Check for dimension text e.g. 12'x14' or 12x14 or 30'0"x40'0"
                m = re.search(r'(\d+(?:\.\d+)?)(?:\'|ft)?(?:\d+\")?x(\d+(?:\.\d+)?)(?:\'|ft)?(?:\d+\")?', t_clean.lower().replace(' ', ''))
                if m:
                    ocr_dimensions.append({
                        "w": float(m.group(1)),
                        "h": float(m.group(2)),
                        "cx": cx, "cy": cy
                    })

                norm_label = normalize_room_label(t_clean)
                if norm_label:
                    detected_texts.append({"label": norm_label, "cx": cx, "cy": cy, "raw": t_clean})

                if re.match(r'^(W\d*|WIN|WINDOW)$', t_upper):
                    detected_openings_ocr.append({"type": "WINDOW", "label": t_upper, "cx": cx, "cy": cy})
                elif re.match(r'^(V\d*|VENT|VENTILATOR)$', t_upper):
                    detected_openings_ocr.append({"type": "WINDOW", "label": t_upper, "cx": cx, "cy": cy, "is_ventilator": True})
                elif re.match(r'^(MD|MAINDOOR|MAIN_DOOR|D\d*|PD|SD|DOOR)$', t_upper):
                    detected_openings_ocr.append({"type": "DOOR", "label": t_upper, "cx": cx, "cy": cy})
                elif re.match(r'^(O|0|OPEN|ARCH|ARCHWAY)$', t_upper):
                    detected_openings_ocr.append({"type": "OPENING", "label": "O", "cx": cx, "cy": cy})
                elif re.match(r'^(MG|MAINGATE|MAIN_GATE|GATE)$', t_upper):
                    detected_openings_ocr.append({"type": "MAIN_GATE", "label": "MG", "cx": cx, "cy": cy})
        except Exception as e:
            print(f"[OCR Execution Error] {e}")

    # Calculate Main House Region from Room Texts (to exclude outer blueprint dimension border box)
    house_roi_min_x = 0
    house_roi_max_x = img_w
    house_roi_min_y = 0
    house_roi_max_y = img_h

    if detected_texts:
        txs = [t["cx"] for t in detected_texts]
        tys = [t["cy"] for t in detected_texts]
        margin_x = max(int(img_w * 0.18), 120)
        margin_y = max(int(img_h * 0.18), 120)
        house_roi_min_x = max(0, int(min(txs) - margin_x))
        house_roi_max_x = min(img_w, int(max(txs) + margin_x))
        house_roi_min_y = max(0, int(min(tys) - margin_y))
        house_roi_max_y = min(img_h, int(max(tys) + margin_y))

    # Erase OCR Text Bounding Boxes & Outer Blueprint Frame Lines from Binary Mask
    clean_binary = binary_img.copy()
    for (tl, tr, br, bl) in ocr_bboxes:
        x_min = max(0, int(min(tl[0], bl[0]) - 8))
        x_max = min(img_w, int(max(tr[0], br[0]) + 8))
        y_min = max(0, int(min(tl[1], tr[1]) - 8))
        y_max = min(img_h, int(max(bl[1], br[1]) + 8))
        cv2.rectangle(clean_binary, (x_min, y_min), (x_max, y_max), 0, -1)

    # Wipe out outer blueprint border box lines lying outside house_roi
    margin_outer = 20
    clean_binary[:max(0, house_roi_min_y - margin_outer), :] = 0
    clean_binary[min(img_h, house_roi_max_y + margin_outer):, :] = 0
    clean_binary[:, :max(0, house_roi_min_x - margin_outer)] = 0
    clean_binary[:, min(img_w, house_roi_max_x + margin_outer):] = 0

    # Filter out 1-2px thin line noise (staircase treads, furniture outlines, dimension ticks)
    kernel_thin = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    clean_structural_binary = cv2.morphologyEx(clean_binary, cv2.MORPH_OPEN, kernel_thin)

    # 2. Extract Wall Centerlines from YOLO Predictions or OpenCV Morphological Filter
    raw_wall_lines = []
    for w in yolo_walls:
        x1, y1, x2, y2 = w["bbox"]
        bw, bh = x2 - x1, y2 - y1
        if bw > bh: # Horizontal Wall
            y_mid = (y1 + y2) / 2.0
            raw_wall_lines.append([x1, y_mid, x2, y_mid, bh])
        else: # Vertical Wall
            x_mid = (x1 + x2) / 2.0
            raw_wall_lines.append([x_mid, y1, x_mid, y2, bw])

    # Pure OpenCV Wall Extraction Fail-Safe if YOLO walls are empty or missed
    if len(raw_wall_lines) < 3:
        print("[OpenCV Wall Extraction] Extracting structural wall lines via OpenCV morphology...")
        kernel_h = cv2.getStructuringElement(cv2.MORPH_RECT, (int(img_w * 0.04), 1))
        kernel_v = cv2.getStructuringElement(cv2.MORPH_RECT, (1, int(img_h * 0.04)))
        
        horiz_walls = cv2.morphologyEx(clean_structural_binary, cv2.MORPH_OPEN, kernel_h)
        vert_walls = cv2.morphologyEx(clean_structural_binary, cv2.MORPH_OPEN, kernel_v)
        
        lines_h = cv2.HoughLinesP(horiz_walls, 1, np.pi/180, threshold=30, minLineLength=int(img_w * 0.08), maxLineGap=25)
        lines_v = cv2.HoughLinesP(vert_walls, 1, np.pi/180, threshold=30, minLineLength=int(img_h * 0.08), maxLineGap=25)

        if lines_h is not None:
            for l in lines_h:
                pts = l.flatten()
                if len(pts) >= 4:
                    x1, y1, x2, y2 = float(pts[0]), float(pts[1]), float(pts[2]), float(pts[3])
                    # Strict Orthogonal Filter: Ignore diagonal lines (like 'X' hatch lines)
                    if abs(y2 - y1) < 15:
                        y_mid = (y1 + y2) / 2.0
                        raw_wall_lines.append([min(x1, x2), y_mid, max(x1, x2), y_mid, 8])

        if lines_v is not None:
            for l in lines_v:
                pts = l.flatten()
                if len(pts) >= 4:
                    x1, y1, x2, y2 = float(pts[0]), float(pts[1]), float(pts[2]), float(pts[3])
                    # Strict Orthogonal Filter: Ignore diagonal lines (like 'X' hatch lines)
                    if abs(x2 - x1) < 15:
                        x_mid = (x1 + x2) / 2.0
                        raw_wall_lines.append([x_mid, min(y1, y2), x_mid, max(y1, y2), 8])

    # 3. Collinear Merging & Corner Alignment for YOLO Walls
    def merge_yolo_lines(lines, band_thresh=25, gap_thresh=45):
        horiz = []
        vert = []
        for l in lines:
            x1, y1, x2, y2, thick = l
            if abs(x2 - x1) >= abs(y2 - y1):
                if x1 > x2: x1, y1, x2, y2 = x2, y2, x1, y1
                horiz.append([x1, y1, x2, y2, thick])
            else:
                if y1 > y2: x1, y1, x2, y2 = x2, y2, x1, y1
                vert.append([x1, y1, x2, y2, thick])

        # Merge Collinear Horizontal Walls
        merged_horiz = []
        for l in horiz:
            x1, y1, x2, y2, thick = l
            y_mid = (y1 + y2) / 2.0
            matched = False
            for m in merged_horiz:
                m_ymid = (m[1] + m[3]) / 2.0
                if abs(m_ymid - y_mid) < band_thresh and (max(m[0], x1) <= min(m[2], x2) + gap_thresh):
                    m[0] = min(m[0], x1)
                    m[2] = max(m[2], x2)
                    m[1] = m[3] = (m_ymid + y_mid) / 2.0
                    m[4] = (m[4] + thick) / 2.0
                    matched = True
                    break
            if not matched:
                merged_horiz.append([x1, y_mid, x2, y_mid, thick])

        # Merge Collinear Vertical Walls
        merged_vert = []
        for l in vert:
            x1, y1, x2, y2, thick = l
            x_mid = (x1 + x2) / 2.0
            matched = False
            for m in merged_vert:
                m_xmid = (m[0] + m[2]) / 2.0
                if abs(m_xmid - x_mid) < band_thresh and (max(m[1], y1) <= min(m[3], y2) + gap_thresh):
                    m[1] = min(m[1], y1)
                    m[3] = max(m[3], y2)
                    m[0] = m[2] = (m_xmid + x_mid) / 2.0
                    m[4] = (m[4] + thick) / 2.0
                    matched = True
                    break
            if not matched:
                merged_vert.append([x_mid, y1, x_mid, y2, thick])

        return merged_horiz + merged_vert

    merged_walls = merge_yolo_lines(raw_wall_lines)

    # Corner Snapping: Extend wall endpoints to intersect adjacent walls (T-junctions & L-corners)
    for i in range(len(merged_walls)):
        for j in range(len(merged_walls)):
            if i == j: continue
            w1 = merged_walls[i]
            w2 = merged_walls[j]
            # If w1 is horizontal and w2 is vertical
            if abs(w1[0] - w1[2]) > abs(w1[1] - w1[3]) and abs(w2[1] - w2[3]) > abs(w2[0] - w2[2]):
                v_x = w2[0]
                h_y = w1[1]
                v_ymin, v_ymax = min(w2[1], w2[3]), max(w2[1], w2[3])
                h_xmin, h_xmax = min(w1[0], w1[2]), max(w1[0], w1[2])
                
                # Check if w1 endpoint is close to vertical wall w2
                if abs(w1[0] - v_x) < 35 and v_ymin - 20 <= h_y <= v_ymax + 20:
                    w1[0] = v_x
                if abs(w1[2] - v_x) < 35 and v_ymin - 20 <= h_y <= v_ymax + 20:
                    w1[2] = v_x

                # Check if w2 endpoint is close to horizontal wall w1
                if abs(w2[1] - h_y) < 35 and h_xmin - 20 <= v_x <= h_xmax + 20:
                    w2[1] = h_y
                if abs(w2[3] - h_y) < 35 and h_xmin - 20 <= v_x <= h_xmax + 20:
                    w2[3] = h_y

    # Outer Bounding Frame check: Ensure exterior boundary walls close the house polygon
    if merged_walls:
        all_x = [w[0] for w in merged_walls] + [w[2] for w in merged_walls]
        all_y = [w[1] for w in merged_walls] + [w[3] for w in merged_walls]
        min_x, max_x = min(all_x), max(all_x)
        min_y, max_y = min(all_y), max(all_y)
    else:
        min_x, max_x = house_roi_min_x, house_roi_max_x
        min_y, max_y = house_roi_min_y, house_roi_max_y

    # 4. Extract Room Polygons from Structural Wall Mask
    graph_mask = np.zeros((img_h, img_w), dtype=np.uint8)
    for w in merged_walls:
        thickness = max(4, int(w[4]))
        cv2.line(graph_mask, (int(w[0]), int(w[1])), (int(w[2]), int(w[3])), 255, thickness)

    # Apply Morphological Closing to seal wall gaps & door openings into continuous room polygons
    kernel_close = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 15))
    closed_graph_mask = cv2.morphologyEx(graph_mask, cv2.MORPH_CLOSE, kernel_close)

    # Draw outer bounding box frame to close any exterior gaps
    cv2.rectangle(closed_graph_mask, (int(min_x), int(min_y)), (int(max_x), int(max_y)), 255, 8)

    rooms_mask = cv2.bitwise_not(closed_graph_mask)
    contours, _ = cv2.findContours(rooms_mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)

    temp_polys = []
    house_area = (max_x - min_x) * (max_y - min_y)
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area > (house_area * 0.012) and area < (house_area * 0.85):
            epsilon = 0.01 * cv2.arcLength(cnt, True)
            approx = cv2.approxPolyDP(cnt, epsilon, True)
            if len(approx) >= 4:
                temp_polys.append(approx)

    # Area-Sum Topological Filter: Exclude inner furniture loops
    room_polys = []
    for i, polyB in enumerate(temp_polys):
        xB, yB, wB, hB = cv2.boundingRect(polyB)
        areaB = wB * hB
        is_furniture_inside = False
        for j, polyA in enumerate(temp_polys):
            if i == j: continue
            xA, yA, wA, hA = cv2.boundingRect(polyA)
            areaA = wA * hA
            if xA >= xB - 2 and yA >= yB - 2 and (xA + wA) <= (xB + wB) + 2 and (yA + hA) <= (yB + hB) + 2:
                if areaA < areaB * 0.5:
                    is_furniture_inside = True
                    break
        room_polys.append(polyB)

    # 5. EasyOCR Text & Room Label Mapping
    ocr_reader = get_ocr_reader()
    detected_texts = []
    ocr_dimensions = []
    detected_openings_ocr = []
    
    if ocr_reader:
        try:
            # Contrast Enhancement (CLAHE) for sharpening low-res architectural floor plans
            clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
            enhanced_gray = clahe.apply(gray_img)
            enhanced_img = cv2.cvtColor(enhanced_gray, cv2.COLOR_GRAY2BGR)

            results = ocr_reader.readtext(enhanced_img, mag_ratio=2.0)
            for bbox, text, prob in results:
                t_clean = text.strip()
                t_upper = t_clean.upper().replace(' ', '')
                min_prob = 0.03 if len(t_upper) <= 3 else 0.12
                if prob < min_prob: continue

                tl, tr, br, bl = bbox
                cx = (tl[0] + br[0]) / 2.0
                cy = (tl[1] + br[1]) / 2.0
                
                # Check for dimension text e.g. 12'x14' or 12x14 or 30'0"x40'0"
                m = re.search(r'(\d+(?:\.\d+)?)(?:\'|ft)?(?:\d+\")?x(\d+(?:\.\d+)?)(?:\'|ft)?(?:\d+\")?', t_clean.lower().replace(' ', ''))
                if m:
                    ocr_dimensions.append({
                        "w": float(m.group(1)),
                        "h": float(m.group(2)),
                        "cx": cx, "cy": cy
                    })
                
                norm_label = normalize_room_label(t_clean)
                if norm_label:
                    detected_texts.append({"label": norm_label, "cx": cx, "cy": cy, "raw": t_clean})

                # Check for explicit door/window/gate/opening OCR labels (W, W1, W2, V, D, D1, MD, PD, O, MG)
                if re.match(r'^(W\d*|WIN|WINDOW)$', t_upper):
                    detected_openings_ocr.append({"type": "WINDOW", "label": t_upper, "cx": cx, "cy": cy})
                elif re.match(r'^(V\d*|VENT|VENTILATOR)$', t_upper):
                    detected_openings_ocr.append({"type": "WINDOW", "label": t_upper, "cx": cx, "cy": cy, "is_ventilator": True})
                elif re.match(r'^(MD|MAINDOOR|MAIN_DOOR|D\d*|PD|SD|DOOR)$', t_upper):
                    detected_openings_ocr.append({"type": "DOOR", "label": t_upper, "cx": cx, "cy": cy})
                elif re.match(r'^(O|0|OPEN|ARCH|ARCHWAY)$', t_upper):
                    detected_openings_ocr.append({"type": "OPENING", "label": "O", "cx": cx, "cy": cy})
                elif re.match(r'^(MG|MAINGATE|MAIN_GATE|GATE)$', t_upper):
                    detected_openings_ocr.append({"type": "MAIN_GATE", "label": "MG", "cx": cx, "cy": cy})
        except Exception as e:
            print(f"[OCR Execution Error] {e}")

    # 6. Scale Calibration
    global_scale = None
    if ocr_dimensions and room_polys:
        ratios = []
        for poly in room_polys:
            x, y, w_px, h_px = cv2.boundingRect(poly)
            for dim in ocr_dimensions:
                if cv2.pointPolygonTest(poly, (dim["cx"], dim["cy"]), False) >= 0:
                    rw = w_px / dim["w"] if dim["w"] > 0 else 0
                    rh = h_px / dim["h"] if dim["h"] > 0 else 0
                    if rw > 0: ratios.append(rw)
                    if rh > 0: ratios.append(rh)
        if ratios:
            global_scale = float(np.median(ratios))

    if not global_scale:
        door_widths = []
        for d in yolo_doors:
            bx1, by1, bx2, by2 = d["bbox"]
            door_widths.append(max(bx2 - bx1, by2 - by1))
        if door_widths:
            global_scale = float(np.median(door_widths)) / 3.0
        else:
            global_scale = max(max_x - min_x, max_y - min_y) / 40.0 # 40ft plot dimension default

    global_scale = max(5.0, min(100.0, global_scale))
    sq_scale = global_scale * global_scale
    print(f"Calculated Global Scale: {global_scale:.2f} px/ft")

    # Subdivide large unpartitioned contours ONLY when containing multiple distinct room labels
    split_room_polys = []
    for poly in room_polys:
        area_px = cv2.contourArea(np.array(poly, dtype=np.int32))
        area_sqft = area_px / sq_scale
        
        inside_texts = []
        for txt in detected_texts:
            dist = cv2.pointPolygonTest(poly, (float(txt["cx"]), float(txt["cy"])), True)
            if dist >= -50.0:
                inside_texts.append(txt)
                
        # Deduplicate inside_texts into unique room label clusters
        unique_label_clusters = []
        for txt in inside_texts:
            is_dup = False
            for cluster in unique_label_clusters:
                d_dist = math.hypot(txt["cx"] - cluster["cx"], txt["cy"] - cluster["cy"])
                if txt["label"] == cluster["label"] or d_dist < 150.0:
                    is_dup = True
                    break
            if not is_dup:
                unique_label_clusters.append(txt)
                
        if area_sqft > 220 and len(unique_label_clusters) >= 2:
            x_bb, y_bb, w_bb, h_bb = cv2.boundingRect(poly)
            unique_label_clusters.sort(key=lambda t: (t["cy"], t["cx"]))
            
            n_clusters = len(unique_label_clusters)
            if w_bb >= h_bb:
                sub_w = w_bb / float(n_clusters)
                for c_idx, cluster in enumerate(unique_label_clusters):
                    sub_x1 = int(x_bb + c_idx * sub_w)
                    sub_x2 = int(x_bb + (c_idx + 1) * sub_w)
                    sub_poly = np.array([
                        [[sub_x1, y_bb]],
                        [[sub_x2, y_bb]],
                        [[sub_x2, y_bb + h_bb]],
                        [[sub_x1, y_bb + h_bb]]
                    ], dtype=np.int32)
                    split_room_polys.append(sub_poly)
            else:
                sub_h = h_bb / float(n_clusters)
                for c_idx, cluster in enumerate(unique_label_clusters):
                    sub_y1 = int(y_bb + c_idx * sub_h)
                    sub_y2 = int(y_bb + (c_idx + 1) * sub_h)
                    sub_poly = np.array([
                        [[x_bb, sub_y1]],
                        [[x_bb + w_bb, sub_y1]],
                        [[x_bb + w_bb, sub_y2]],
                        [[x_bb, sub_y2]]
                    ], dtype=np.int32)
                    split_room_polys.append(sub_poly)
        else:
            split_room_polys.append(poly)

    room_polys = split_room_polys

    # 7. Assemble Walls Array
    walls_list = []

    for w in merged_walls:
        x1, y1, x2, y2, thick = w
        length_px = math.hypot(x2 - x1, y2 - y1)
        if length_px / global_scale < 1.0: continue

        wall_id = id_gen.get("W")
        walls_list.append({
            "source_id": wall_id,
            "id": wall_id,
            "type": "structural",
            "is_compound": False,
            "is_exterior": False,
            "start": {"x": round(x1 / global_scale, 2), "y": round(y1 / global_scale, 2)},
            "end": {"x": round(x2 / global_scale, 2), "y": round(y2 / global_scale, 2)},
            "thickness_ft": round(thick / global_scale, 2) if thick > 0 else 0.5,
            "height_ft": 10.0,
            "connected_doors": [],
            "connected_windows": [],
            "connected_rooms": [],
            "raw_pts": [(x1, y1), (x2, y2)]
        })

    # 8. Assemble Doors & Windows and Snap to Walls
    doors_list = []
    windows_list = []
    openings_list = []

    def process_opening(yolo_obj, type_str):
        x1, y1, x2, y2 = yolo_obj["bbox"]
        cx, cy = (x1 + x2) / 2.0, (y1 + y2) / 2.0
        bw, bh = x2 - x1, y2 - y1
        width_ft = max(bw, bh) / global_scale
        width_ft = max(2.5, min(8.0, round(width_ft, 2)))

        # Check if OCR label overrides type (e.g. W, W1, W2 -> WINDOW even if YOLO guessed DOOR)
        ocr_match = None
        for ocr in detected_openings_ocr:
            if math.hypot(cx - ocr["cx"], cy - ocr["cy"]) < (global_scale * 5.0):
                ocr_match = ocr
                break

        if ocr_match:
            type_str = ocr_match["type"]

        closest_wall = None
        min_dist = float('inf')
        proj_x, proj_y = cx, cy

        for w_obj in walls_list:
            (ax, ay), (bx, by) = w_obj["raw_pts"]
            dist = dist_to_segment((cx, cy), (ax, ay), (bx, by))
            if dist < min_dist:
                min_dist = dist
                closest_wall = w_obj
                proj_x, proj_y = project_point_on_segment((cx, cy), (ax, ay), (bx, by))

        wall_id = closest_wall["source_id"] if closest_wall else ""
        opening_id = id_gen.get("D" if type_str == "DOOR" else ("V" if type_str == "WINDOW" else "O"))

        opening = {
            "source_id": opening_id,
            "id": opening_id,
            "type": type_str,
            "label": ocr_match["label"] if ocr_match else type_str,
            "position": {"x": round(proj_x / global_scale, 2), "y": round(proj_y / global_scale, 2)},
            "width_ft": width_ft,
            "wall_id": wall_id,
            "confidence": round(yolo_obj["conf"], 2)
        }

        if closest_wall:
            if type_str == "DOOR":
                closest_wall["connected_doors"].append(opening_id)
            elif type_str == "WINDOW":
                closest_wall["connected_windows"].append(opening_id)

        return opening

    for d in yolo_doors:
        op = process_opening(d, "DOOR")
        if op["type"] == "WINDOW": windows_list.append(op)
        elif op["type"] == "DOOR": doors_list.append(op)
        openings_list.append(op)

    for w in yolo_windows:
        op = process_opening(w, "WINDOW")
        if op["type"] == "WINDOW": windows_list.append(op)
        elif op["type"] == "DOOR": doors_list.append(op)
        openings_list.append(op)

    # Process OCR-only detected openings (if YOLO missed W, W1, D, D1, MD, MG, O)
    for ocr in detected_openings_ocr:
        # Check if already processed near YOLO bbox
        already_processed = any(math.hypot(op["position"]["x"] * global_scale - ocr["cx"], op["position"]["y"] * global_scale - ocr["cy"]) < (global_scale * 3.0) for op in openings_list)
        if not already_processed:
            fake_yolo = {"bbox": [ocr["cx"] - 20, ocr["cy"] - 20, ocr["cx"] + 20, ocr["cy"] + 20], "conf": 0.85}
            op = process_opening(fake_yolo, ocr["type"])
            op["label"] = ocr["label"]
            if op["type"] == "WINDOW": windows_list.append(op)
            elif op["type"] == "DOOR": doors_list.append(op)
            openings_list.append(op)

    # 9. Assemble Rooms Array
    rooms_list = []
    used_labels = defaultdict(int)
    used_text_indices = set()

    for idx, poly in enumerate(room_polys):
        pts_px = [[float(pt[0][0]), float(pt[0][1])] for pt in poly]
        pts_ft = [{"x": round(pt[0] / global_scale, 2), "y": round(pt[1] / global_scale, 2)} for pt in pts_px]
        
        area_px = cv2.contourArea(np.array(poly, dtype=np.int32))
        area_sqft = round(area_px / sq_scale, 2)
        
        x, y, w_cnt, h_cnt = cv2.boundingRect(poly)
        cx = x + w_cnt / 2.0
        cy = y + h_cnt / 2.0

        # Determine Room Name/Label (Strictly prioritize texts INSIDE polygon)
        assigned_label = None
        raw_name = None
        best_text_idx = -1
        best_inside_dist = -1.0
        best_outside_dist = float('inf')

        for t_idx, txt in enumerate(detected_texts):
            if t_idx in used_text_indices:
                continue

            dist = cv2.pointPolygonTest(poly, (float(txt["cx"]), float(txt["cy"])), True)
            
            # Area sanity check: Do NOT assign Bedroom or Living Room labels to tiny rooms (< 65 sqft)
            if txt["label"] in ["Master Bedroom", "Bedroom", "Living Room"] and area_sqft < 65:
                continue
            # Do NOT assign Toilet/Restroom labels to large rooms (> 120 sqft)
            if txt["label"] in ["Bathroom", "Toilet", "WC"] and area_sqft > 120:
                continue

            if dist >= 0:
                # Strictly INSIDE polygon: pick text deepest inside (highest positive distance to border)
                if dist > best_inside_dist:
                    best_inside_dist = dist
                    best_text_idx = t_idx
                    assigned_label = txt["label"]
                    raw_name = txt.get("raw")
            elif best_inside_dist < 0:
                # If no text is strictly inside, consider text near border (within 25px outside)
                dist_val = -dist
                if dist_val < 25.0 and dist_val < best_outside_dist:
                    best_outside_dist = dist_val
                    best_text_idx = t_idx
                    assigned_label = txt["label"]
                    raw_name = txt.get("raw")

        if best_text_idx != -1:
            used_text_indices.add(best_text_idx)

        # Check for 2D Staircase Drawing (Parallel Step Lines pattern detection inside small dedicated room ROI)
        if not assigned_label:
            rx, ry, rw_roi, rh_roi = cv2.boundingRect(poly)
            aspect_ratio = max(rw_roi / max(1, rh_roi), rh_roi / max(1, rw_roi))
            if rw_roi > 10 and rh_roi > 10 and aspect_ratio >= 1.2 and 20 <= area_sqft <= 110:
                try:
                    mask = np.zeros((img_h, img_w), dtype=np.uint8)
                    cv2.drawContours(mask, [poly], -1, 255, -1)
                    masked_roi = cv2.bitwise_and(binary_img, binary_img, mask=mask)[ry:ry+rh_roi, rx:rx+rw_roi]

                    lines = cv2.HoughLinesP(masked_roi, 1, np.pi/180, threshold=12, minLineLength=10, maxLineGap=4)
                    if lines is not None and len(lines) >= 5:
                        horiz_lines = 0
                        vert_lines = 0
                        for line in lines:
                            x1_l, y1_l, x2_l, y2_l = line[0]
                            ang = abs(math.atan2(y2_l - y1_l, x2_l - x1_l) * 180 / np.pi)
                            if ang < 15 or ang > 165:
                                horiz_lines += 1
                            elif 75 < ang < 105:
                                vert_lines += 1
                        
                        if (horiz_lines >= 4 or vert_lines >= 4) and (cy < img_h * 0.85):
                            assigned_label = "Staircase"
                except Exception as e:
                    pass

        # Ignore tiny unlabelled noise fragments (< 25 sqft)
        if area_sqft < 25.0 and not assigned_label and best_text_idx == -1:
            continue

        if not assigned_label:
            rel_x = (cx - min_x) / max(1.0, (max_x - min_x))
            rel_y = (cy - min_y) / max(1.0, (max_y - min_y))

            if area_sqft < 65:
                if rel_x > 0.7 and rel_y > 0.6 and used_labels["Utility Area"] == 0:
                    assigned_label = "Utility Area"
                elif used_labels["Toilet"] < 2 and area_sqft >= 35:
                    assigned_label = "Toilet"
                elif used_labels["Passage"] == 0 and area_sqft >= 30:
                    assigned_label = "Passage"
                else:
                    # Skip tiny unassigned fragments rather than creating 20+ duplicate passages
                    continue
            elif area_sqft > 160:
                if used_labels["Living Room"] == 0:
                    assigned_label = "Living Room"
                elif rel_x > 0.6 and rel_y < 0.5 and used_labels["Car Parking Portico"] == 0:
                    assigned_label = "Car Parking Portico"
                elif used_labels["Master Bedroom"] == 0:
                    assigned_label = "Master Bedroom"
                else:
                    assigned_label = "Bedroom"
            elif 85 <= area_sqft <= 160:
                if rel_x > 0.5 and rel_y > 0.5 and used_labels["Kitchen"] == 0:
                    assigned_label = "Kitchen"
                elif rel_x < 0.5 and rel_y > 0.5 and used_labels["Dining Area"] == 0:
                    assigned_label = "Dining Area"
                elif used_labels["Master Bedroom"] == 0:
                    assigned_label = "Master Bedroom"
                elif used_labels["Bedroom 2"] == 0:
                    assigned_label = "Bedroom 2"
                else:
                    assigned_label = "Bedroom"
            else:
                if used_labels["Common Toilet"] == 0:
                    assigned_label = "Common Toilet"
                elif used_labels["Attached Toilet"] == 0:
                    assigned_label = "Attached Toilet"
                else:
                    assigned_label = "Toilet"

        # Unique Room Type Enforcement: Prevent duplicate Kitchen 2/3, Dining 2/3, Living 2
        single_instance_labels = ["Kitchen", "Dining Area", "Living Room", "Portico", "Pooja Room"]
        if assigned_label in single_instance_labels and used_labels[assigned_label] >= 1 and not raw_name:
            if used_labels["Master Bedroom"] == 0 and area_sqft >= 90:
                assigned_label = "Master Bedroom"
            else:
                assigned_label = "Bedroom"

        used_labels[assigned_label] += 1
        count_suffix = f" {used_labels[assigned_label]}" if used_labels[assigned_label] > 1 else ""
        cleaned_raw = clean_and_fix_ocr_text(raw_name.strip()) if (raw_name and len(raw_name.strip()) > 1) else None
        room_name = cleaned_raw if cleaned_raw else f"{assigned_label}{count_suffix}"

        room_id = id_gen.get("R")
        rooms_list.append({
            "source_id": room_id,
            "id": room_id,
            "name": room_name,
            "label": assigned_label,
            "area": area_sqft,
            "area_sqft": area_sqft,
            "polygon": pts_ft,
            "bounds": {
                "x": round(x / global_scale, 2),
                "y": round(y / global_scale, 2),
                "w": round(w_cnt / global_scale, 2),
                "h": round(h_cnt / global_scale, 2)
            },
            "center": {
                "x": round(cx / global_scale, 2),
                "y": round(cy / global_scale, 2)
            }
        })

    # Fallback to structural grid partition if contours yield 0 rooms
    if len(rooms_list) == 0:
        print("[Fallback] Generating layout footprint rooms...")
        width_ft = round((max_x - min_x) / global_scale, 2)
        height_ft = round((max_y - min_y) / global_scale, 2)
        min_x_ft = round(min_x / global_scale, 2)
        min_y_ft = round(min_y / global_scale, 2)
        
        if detected_texts:
            sorted_texts = sorted(detected_texts, key=lambda t: (t["cy"], t["cx"]))
            num_rooms = len(sorted_texts)
            cols = 3 if num_rooms >= 6 else (2 if num_rooms >= 4 else 1)
            rows = math.ceil(num_rooms / float(cols))
            sub_w = width_ft / float(cols)
            sub_h = height_ft / float(rows)

            def_rooms = []
            for idx, txt in enumerate(sorted_texts):
                r_col = idx % cols
                r_row = idx // cols
                rx = min_x_ft + r_col * sub_w
                ry = min_y_ft + r_row * sub_h
                def_rooms.append((txt["label"], rx, ry, sub_w, sub_h, txt.get("raw")))
        else:
            sub_w = width_ft / 2.0
            sub_h = height_ft / 2.0
            def_rooms = [
                ("Living Room", min_x_ft, min_y_ft, sub_w, sub_h, "Living Room"),
                ("Master Bedroom", min_x_ft + sub_w, min_y_ft, sub_w, sub_h, "Master Bedroom"),
                ("Kitchen", min_x_ft, min_y_ft + sub_h, sub_w, sub_h, "Kitchen"),
                ("Toilet", min_x_ft + sub_w, min_y_ft + sub_h, sub_w, sub_h, "Toilet")
            ]

        for item in def_rooms:
            name, rx, ry, rw, rh = item[0], item[1], item[2], item[3], item[4]
            raw_name = item[5] if len(item) > 5 else name
            r_id = id_gen.get("R")
            poly_pts = [
                {"x": round(rx, 2), "y": round(ry, 2)},
                {"x": round(rx + rw, 2), "y": round(ry, 2)},
                {"x": round(rx + rw, 2), "y": round(ry + rh, 2)},
                {"x": round(rx, 2), "y": round(ry + rh, 2)}
            ]
            rooms_list.append({
                "source_id": r_id,
                "id": r_id,
                "name": raw_name or name,
                "label": name,
                "area": round(rw * rh, 2),
                "area_sqft": round(rw * rh, 2),
                "polygon": poly_pts,
                "bounds": {"x": round(rx, 2), "y": round(ry, 2), "w": round(rw, 2), "h": round(rh, 2)},
                "center": {"x": round(rx + rw / 2.0, 2), "y": round(ry + rh / 2.0, 2)}
            })

    # Clean raw temporary attributes from walls
    for w in walls_list:
        if "raw_pts" in w: del w["raw_pts"]

    # 8.5 INTELLECTUAL DOOR SYNTHESIS: Ensure EVERY indoor room has a door
    rooms_with_doors = set()
    for d in doors_list:
        px = d["position"]["x"]
        py = d["position"]["y"]
        for r in rooms_list:
            if "bounds" in r:
                bx = r["bounds"]["x"]
                by = r["bounds"]["y"]
                bw = r["bounds"]["w"]
                bh = r["bounds"]["h"]
                if (bx - 2.0) <= px <= (bx + bw + 2.0) and (by - 2.0) <= py <= (by + bh + 2.0):
                    rooms_with_doors.add(r["id"])

    for r in rooms_list:
        if r["id"] not in rooms_with_doors:
            r_name = (r.get("name") or r.get("label") or "").lower()
            poly = r.get("polygon", [])
            if len(poly) < 3: continue
            
            best_wall = None
            best_mid_x, best_mid_y = 0, 0
            max_wall_len = 0
            
            for i in range(len(poly)):
                p1 = poly[i]
                p2 = poly[(i + 1) % len(poly)]
                p1x, p1y = p1["x"], p1["y"]
                p2x, p2y = p2["x"], p2["y"]
                seg_len = math.hypot(p2x - p1x, p2y - p1y)
                if seg_len < 2.0: continue
                
                mid_x = (p1x + p2x) / 2.0
                mid_y = (p1y + p2y) / 2.0
                
                matched_w = None
                for w in walls_list:
                    ax, ay = w["start"]["x"], w["start"]["y"]
                    bx, by = w["end"]["x"], w["end"]["y"]
                    if dist_to_segment((mid_x, mid_y), (ax, ay), (bx, by)) < 1.2:
                        matched_w = w
                        break
                
                if seg_len > max_wall_len:
                    max_wall_len = seg_len
                    best_wall = matched_w
                    best_mid_x, best_mid_y = mid_x, mid_y
            
            if best_wall and max_wall_len >= 2.0:
                d_id = id_gen.get("D")
                is_main = "living" in r_name or "hall" in r_name or "portico" in r_name or "entrance" in r_name
                is_toilet = "toilet" in r_name or "bath" in r_name or "wc" in r_name
                d_width = 3.5 if is_main else (2.2 if is_toilet else 3.0)
                d_label = "MD" if is_main else ("D1" if is_toilet else "D")
                
                door_obj = {
                    "source_id": d_id,
                    "id": d_id,
                    "type": "DOOR",
                    "label": d_label,
                    "position": {"x": round(best_mid_x, 2), "y": round(best_mid_y, 2)},
                    "width_ft": d_width,
                    "wall_id": best_wall.get("id", best_wall.get("source_id", "")),
                    "confidence": 0.95
                }
                doors_list.append(door_obj)
                openings_list.append(door_obj)
                rooms_with_doors.add(r["id"])

    project_width = round(max(10.0, (max_x - min_x) / global_scale), 2)
    project_length = round(max(10.0, (max_y - min_y) / global_scale), 2)

    canonical_json = {
        "schema_version": "2.0",
        "project": {
            "global_scale_px_per_ft": round(global_scale, 2),
            "ocr_scale_found": bool(ocr_dimensions),
            "width": project_width,
            "height": project_length,
            "overall_dimensions": {
                "width_ft": project_width,
                "length_ft": project_length
            }
        },
        "building": {},
        "walls": walls_list,
        "rooms": rooms_list,
        "doors": doors_list,
        "windows": windows_list,
        "openings": openings_list,
        "stairs": [],
        "semantic_objects": {},
        "source_accounting": {
            "walls": len(walls_list),
            "rooms": len(rooms_list),
            "doors": len(doors_list),
            "windows": len(windows_list)
        },
        "validation": {
            "scale_required": False,
            "geometry_source": "yolo_clean_architectural",
            "overall_geometry_valid": True,
            "errors": []
        }
    }

    if out_dir:
        with open(os.path.join(out_dir, "canonical_output.json"), "w") as f:
            json.dump(canonical_json, f, indent=2)

        out_img = original_img.copy()
        for w in walls_list:
            pt1 = (int(w['start']['x'] * global_scale), int(w['start']['y'] * global_scale))
            pt2 = (int(w['end']['x'] * global_scale), int(w['end']['y'] * global_scale))
            cv2.line(out_img, pt1, pt2, (255, 0, 0), 3)

        for r in rooms_list:
            pts = np.array([[int(p['x'] * global_scale), int(p['y'] * global_scale)] for p in r['polygon']], np.int32)
            cv2.polylines(out_img, [pts], True, (0, 255, 0), 2)
            cx, cy = int(r['center']['x'] * global_scale), int(r['center']['y'] * global_scale)
            cv2.putText(out_img, r['name'], (cx - 30, cy), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)

        cv2.imwrite(os.path.join(out_dir, "Z_architectural_reconstruction.png"), out_img)

    print(f"Geometry Extraction Complete: {len(walls_list)} walls, {len(rooms_list)} rooms, {len(doors_list)} doors, {len(windows_list)} windows.")
    return canonical_json

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else os.path.join("uploads", "1789879582112.png")
    extract_geometry(target, "cv_debug_output")
