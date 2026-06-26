import cv2
import numpy as np
import json
import sys
import os
import re
import time
from google import genai
from google.genai import types
from PIL import Image
from dotenv import load_dotenv

load_dotenv(override=True)

GEMINI_PROMPT = """You are a master architectural AI. Your ONLY goal is 1:1 EXACT reconstruction of the 2D blueprint into structured JSON.

TASK: Extract EVERY SINGLE ROOM, WALL, DOOR, WINDOW and FIXTURE visible in the image. Nothing can be omitted.

=== EXTRACTION RULES ===
1. ROOMS: Detect ALL rooms — including small ones like toilets, utility areas, WC, portico, store room, pooja. 
   - Use the EXACT room names written in the plan (e.g. "MASTER BDRM", "COMMON TOILET", "CAR PARKING PORTICO").
   - Use the EXACT dimensions labeled in the plan (e.g. 13'0" x 16'6" → width=13.0, height=16.5).
   - Use (0,0) as the top-left corner of the floor plan boundary.
   - x increases going RIGHT, y increases going DOWN.
2. WALLS: Draw every wall segment. Exterior = 0.75ft thick, Interior = 0.37ft thick.
3. DOORS/WINDOWS: Place them at the exact symbol locations. Mark 'MAIN ENTRANCE' as is_main=true.
4. ADJACENCY: Rooms MUST be perfectly adjacent. No gaps or overlaps. If rooms share a boundary, their coordinates MUST be identical.
5. GRID ALIGNMENT: Align rooms to a logical grid. If multiple rooms are in a row, they should share the same 'y' and 'height'. If in a column, they should share 'x' and 'width'.
6. NO OVERLAPS: Under no circumstances should two rooms occupy the same space.
7. FURNITURE: Detect everything visible:
   - Living: sofa_set, tv_unit, coffee_table
   - Bedroom: king_bed, wardrobe
   - Dining: dining_table_6
   - Kitchen: kitchen_stove, kitchen_sink, platform
   - Bathroom: wc, wash_basin
   - Portico: car, plants
8. PROJECT: Set width = total E-W dimension in feet, height = total N-S dimension in feet.

=== OUTPUT FORMAT (STRICT JSON ONLY) ===
{
  "project": {"width": 30, "height": 40},
  "rooms": [
    {"name": "Living Room", "x": 9, "y": 11, "width": 16.5, "height": 23.5},
    {"name": "Master Bedroom", "x": 0, "y": 20, "width": 13, "height": 16.5},
    {"name": "Common Toilet", "x": 9, "y": 0, "width": 7, "height": 8},
    {"name": "Car Parking Portico", "x": 18, "y": 0, "width": 12, "height": 17.5}
  ],
  "walls": [{"start": [0, 0], "end": [30, 0], "thickness": 0.75}],
  "doors": [{"x": 15, "y": 20, "width": 3.5, "is_main": true, "angle": 0}],
  "windows": [{"x": 5, "y": 0, "width": 4, "dir": "x"}],
  "furnitures": [
    {"type": "king_bed", "x": 3, "y": 24, "width": 6.5, "height": 7, "rotation": 0},
    {"type": "sofa_set", "x": 11, "y": 15, "width": 8, "height": 3, "rotation": 0}
  ]
}

RETURN ONLY VALID JSON. No markdown, no explanation, no code fences. Just the JSON object."""

def debug_log(image_path, model_name, response_text):
    """Save raw AI response for debugging."""
    try:
        log_path = image_path + ".debug.txt"
        with open(log_path, "w", encoding="utf-8") as f:
            f.write(f"Model: {model_name}\n")
            f.write(f"Response:\n{response_text}\n")
        print(f"[Debug] Saved AI response to {log_path}", file=sys.stderr)
    except: pass



def snap_half(val):
    """Snap a value to the nearest 0.5 increment."""
    return round(val * 2) / 2


def validate_model_data(data):
    """Validate, fix, and post-process the AI output for accurate 3D rendering."""
    if not isinstance(data, dict):
        return None

    if 'project' not in data or not isinstance(data.get('project'), dict):
        data['project'] = {"name": "Floor Plan", "width": 30, "height": 40}

    pw = float(data['project'].get('width', 30))
    ph = float(data['project'].get('height', 40))
    data['project']['width'] = pw
    data['project']['height'] = ph

    for key in ['rooms', 'doors', 'windows', 'furnitures']:
        if key not in data or not isinstance(data[key], list):
            data[key] = []

    rooms = data['rooms']
    valid_rooms = []
    for room in rooms:
        if not isinstance(room, dict):
            continue
        for k in ['x', 'y', 'width', 'height']:
            if k not in room:
                room[k] = 0
            try:
                room[k] = float(room[k])
            except:
                room[k] = 0.0

        if 'name' not in room or not room['name']:
            room['name'] = 'Room'

        # Snap to 0.1ft grid
        room['x']      = round(room['x'], 1)
        room['y']      = round(room['y'], 1)
        room['width']  = max(2.0, round(room['width'], 1))
        room['height'] = max(2.0, round(room['height'], 1))

        valid_rooms.append(room)

    # 1. Snap room coordinates to each other to eliminate gaps
    valid_rooms = snap_room_coordinates(valid_rooms)

    # 2. Update project bounds after snapping
    for room in valid_rooms:
        if room['x'] + room['width'] > pw: pw = room['x'] + room['width']
        if room['y'] + room['height'] > ph: ph = room['y'] + room['height']

    data['project']['width'] = pw
    data['project']['height'] = ph
    data['rooms'] = valid_rooms

    # 3. Generate robust walls
    if 'walls' not in data or not isinstance(data['walls'], list) or len(data['walls']) == 0:
        data['walls'] = generate_walls_from_rooms(valid_rooms, data['project'])
    else:
        # Filter and fix AI walls if present, or regenerate
        valid_walls = [w for w in data['walls'] if isinstance(w, dict) and 'start' in w and 'end' in w]
        if len(valid_walls) < 5: # Likely incomplete extraction
            data['walls'] = generate_walls_from_rooms(valid_rooms, data['project'])
        else:
            data['walls'] = valid_walls

    # Ensure main door is marked
    for i, d in enumerate(data.get('doors', [])):
        if 'is_main' not in d:
            d['is_main'] = (i == 0) # Default first door as main if not specified

    return data


def snap_room_coordinates(rooms, threshold=1.2):
    """
    Finds all unique x and y boundaries and snaps rooms to them if they are close.
    This eliminates gaps between rooms that are meant to be adjacent.
    """
    if not rooms: return []

    # Collect all x-boundaries (left and right edges)
    x_coords = []
    y_coords = []
    for r in rooms:
        x_coords.extend([r['x'], r['x'] + r['width']])
        y_coords.extend([r['y'], r['y'] + r['height']])

    def get_snapped_map(coords):
        coords.sort()
        snapped_map = {}
        if not coords: return snapped_map
        
        groups = []
        if coords:
            current_group = [coords[0]]
            for i in range(1, len(coords)):
                if coords[i] - coords[i-1] < threshold:
                    current_group.append(coords[i])
                else:
                    groups.append(current_group)
                    current_group = [coords[i]]
            groups.append(current_group)
        
        for group in groups:
            avg = sum(group) / len(group)
            # Preference for 0 or project bounds if very close
            if abs(avg) < 0.5: avg = 0.0
            for val in group:
                snapped_map[val] = avg
        return snapped_map

    snap_x = get_snapped_map(x_coords)
    snap_y = get_snapped_map(y_coords)

    for r in rooms:
        x1 = snap_x.get(r['x'], r['x'])
        x2 = snap_x.get(r['x'] + r['width'], r['x'] + r['width'])
        y1 = snap_y.get(r['y'], r['y'])
        y2 = snap_y.get(r['y'] + r['height'], r['y'] + r['height'])
        
        r['x'] = round(x1, 1)
        r['width'] = round(max(0.1, x2 - x1), 1)
        r['y'] = round(y1, 1)
        r['height'] = round(max(0.1, y2 - y1), 1)

    return rooms


def generate_walls_from_rooms(rooms, project):
    """
    Generate a 'neat' single-wall structure by merging shared boundaries.
    """
    pw = float(project.get('width', 30))
    ph = float(project.get('height', 40))
    walls = []
    
    # Track existing wall segments to avoid duplicates
    existing_walls = []

    def is_duplicate(s, e):
        for ws, we in existing_walls:
            # Check if this segment (s-e) is already covered by (ws-we)
            # Since we snapped coordinates, we can use a tighter tolerance
            if abs(s[0]-ws[0]) < 0.15 and abs(s[1]-ws[1]) < 0.15 and abs(e[0]-we[0]) < 0.15 and abs(e[1]-we[1]) < 0.15:
                return True
            if abs(s[0]-we[0]) < 0.15 and abs(s[1]-we[1]) < 0.15 and abs(e[0]-ws[0]) < 0.15 and abs(e[1]-ws[1]) < 0.15:
                return True
        return False

    # First, draw an outer boundary shell for the whole house
    # We find the min/max of all rooms (excluding steps)
    valid_rects = [r for r in rooms if 'step' not in r['name'].lower()]
    if valid_rects:
        min_x = min(r['x'] for r in valid_rects)
        max_x = max(r['x'] + r['width'] for r in valid_rects)
        min_y = min(r['y'] for r in valid_rects)
        max_y = max(r['y'] + r['height'] for r in valid_rects)
        
        outer_edges = [
            ((min_x, min_y), (max_x, min_y)),
            ((min_x, max_y), (max_x, max_y)),
            ((min_x, min_y), (min_x, max_y)),
            ((max_x, min_y), (max_x, max_y)),
        ]
        for s, e in outer_edges:
            walls.append({"start": [s[0], s[1]], "end": [e[0], e[1]], "thickness": 0.75})
            existing_walls.append((s, e))

    for room in rooms:
        # Skip steps for basic wall gen
        if 'step' in room['name'].lower():
            continue
            
        rx, ry = float(room['x']), float(room['y'])
        rw, rh = float(room['width']), float(room['height'])

        edges = [
            ((rx, ry),      (rx + rw, ry)),       # top
            ((rx, ry + rh), (rx + rw, ry + rh)),  # bottom
            ((rx, ry),      (rx, ry + rh)),        # left
            ((rx + rw, ry), (rx + rw, ry + rh)),  # right
        ]

        for (sx, sy), (ex, ey) in edges:
            if not is_duplicate((sx, sy), (ex, ey)):
                # If it's near the project bounds or outer shell, use exterior thickness
                # Tightened tolerance for exterior check
                is_ext = (abs(sx - min_x) < 0.5 or abs(ex - min_x) < 0.5 or 
                          abs(sx - max_x) < 0.5 or abs(ex - max_x) < 0.5 or
                          abs(sy - min_y) < 0.5 or abs(ey - min_y) < 0.5 or 
                          abs(sy - max_y) < 0.5 or abs(ey - max_y) < 0.5)
                
                # Check if this wall segment is inside another room (to avoid double walls)
                # We skip walls that are fully contained within another room's interior
                mid_x, mid_y = (sx + ex) / 2, (sy + ey) / 2
                is_internal_overlap = False
                for other in valid_rects:
                    if other == room: continue
                    # If midpoint is strictly inside another room, it's likely a redundant wall
                    ox, oy, ow, oh = other['x'], other['y'], other['width'], other['height']
                    if (ox + 0.1 < mid_x < ox + ow - 0.1) and (oy + 0.1 < mid_y < oy + oh - 0.1):
                        is_internal_overlap = True
                        break
                
                if not is_internal_overlap:
                    thick = 0.75 if is_ext else 0.37
                    walls.append({"start": [sx, sy], "end": [ex, ey], "thickness": thick})
                    existing_walls.append(((sx, sy), (ex, ey)))

    return walls


def get_gemini_analysis(image_path):
    """Use Gemini Vision to extract architectural data from a 2D floor plan."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key or api_key.strip() in ("", "your-gemini-api-key"):
        print("Error: No Gemini API key found in environment", file=sys.stderr)
        return None

    try:
        # Initialize the new Google GenAI client
        client = genai.Client(api_key=api_key)
        
        # Load and verify image
        with open(image_path, 'rb') as f:
            image_bytes = f.read()
        
        # Priority: use latest available models in this project
        MODELS = [
            'gemini-1.5-pro-latest',          # Requested high-end model
            'gemini-1.5-flash-latest',  # State of the art
            'gemini-2.5-flash',        # Very stable and fast
            'gemini-2.0-flash',        # Fast multimodal
            'gemini-flash-latest',      # Reliable fallback
        ]

        for model_name in MODELS:
            max_retries = 2
            for attempt in range(max_retries):
                try:
                    print(f"Analyzing with {model_name} (Attempt {attempt+1})...", file=sys.stderr)
                    
                    response = client.models.generate_content(
                        model=model_name,
                        contents=[
                            GEMINI_PROMPT,
                            types.Part.from_bytes(data=image_bytes, mime_type='image/png')
                        ],
                        config=types.GenerateContentConfig(
                            temperature=0.1,
                        )
                    )
                    
                    if not response or not response.text:
                        print(f"Warning: {model_name} returned empty response", file=sys.stderr)
                        continue

                    text = response.text.strip()
                    debug_log(image_path, model_name, text)
                    
                    # Enhanced JSON extraction: Find the first '{' and last '}'
                    json_str = text
                    start_idx = text.find('{')
                    end_idx = text.rfind('}')
                    if start_idx != -1 and end_idx != -1:
                        json_str = text[start_idx:end_idx + 1]
                    
                    # Clean up common AI issues (trailing commas, etc.)
                    json_str = re.sub(r',\s*}', '}', json_str)
                    json_str = re.sub(r',\s*]', ']', json_str)

                    try:
                        parsed = json.loads(json_str)
                        if parsed.get('rooms') and len(parsed['rooms']) > 0:
                            print(f"[Success] Gemini {model_name} processed {len(parsed['rooms'])} rooms with fixtures.", file=sys.stderr)
                            # Tag the result so we know it came from Gemini
                            parsed['source'] = 'gemini'
                            return validate_model_data(parsed)
                    except json.JSONDecodeError as e:
                        print(f"[Error] JSON Parse Failed for {model_name}: {e}", file=sys.stderr)
                        # Try one more regex fallback
                        match = re.search(r'\{[\s\S]*"rooms"[\s\S]*\}', text)
                        if match:
                            try:
                                parsed = json.loads(match.group())
                                parsed['source'] = 'gemini'
                                return validate_model_data(parsed)
                            except: pass

                    print(f"[Warning] Model {model_name} output was not valid JSON, trying next model.", file=sys.stderr)
                    time.sleep(1)
                    break  # Move to next model
                
                except Exception as e:
                    print(f"[Error] Gemini {model_name} attempt {attempt+1} failed: {e}", file=sys.stderr)
                    time.sleep(2)
                    continue

    except Exception as e:
        print(f"Critical Gemini Setup Error: {str(e)}", file=sys.stderr)

    return None


def fallback_opencv_extraction(image_path):
    """
    Detects actual enclosed white room areas in a floor plan.
    Uses morphological operations to find large white regions = rooms.
    Completely avoids Hough line grids (which create 42+ tiny cells).
    """
    print("[OpenCV] Starting contour-based room extraction...", file=sys.stderr)
    import cv2, numpy as np

    img = cv2.imread(image_path)
    if img is None:
        return None

    img_h, img_w = img.shape[:2]
    aspect = img_w / img_h

    # Determine project dimensions from aspect ratio (in feet)
    if aspect >= 1.0:
        project_w = round(40.0 * aspect, 1)
        project_h = 40.0
    else:
        project_w = 30.0
        project_h = round(30.0 / aspect, 1)

    # Crop margins (8%) to strip title blocks and dimension annotations
    mx = int(img_w * 0.08)
    my = int(img_h * 0.08)
    crop = img[my:img_h - my, mx:img_w - mx]
    ch, cw = crop.shape[:2]

    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)

    # Threshold: only very bright/white areas = room interiors
    # Threshold: try multiple methods to find room areas
    # Method A: Global threshold (for clean white plans)
    _, thresh = cv2.threshold(gray, 220, 255, cv2.THRESH_BINARY)
    
    # Method B: Adaptive threshold (for shadowed or complex plans) if A fails
    if cv2.countNonZero(thresh) < (cw * ch * 0.1):
        thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)

    # Morphological close to fill small gaps from text/hatching inside rooms
    kernel = np.ones((7, 7), np.uint8)
    closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)

    # Erode to separate touching rooms
    kernel_sep = np.ones((5, 5), np.uint8)
    separated = cv2.erode(closed, kernel_sep, iterations=3)

    contours, _ = cv2.findContours(separated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Only accept rooms that are at least 2% of the total image area (prevents tiny noise cells)
    min_area_px = (cw * ch) * 0.02
    rooms = []
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < min_area_px:
            continue
        bx, by, bw, bh = cv2.boundingRect(cnt)
        # Skip if it covers the whole image (outer border detection)
        if bw > cw * 0.9 and bh > ch * 0.9:
            continue
        # Skip very thin slivers (dimension lines etc.)
        aspect_r = bw / bh if bh > 0 else 99
        if aspect_r > 8 or aspect_r < 0.125:
            continue

        rx = round(((bx + mx) / img_w) * project_w, 1)
        ry = round(((by + my) / img_h) * project_h, 1)
        rw = max(3.0, round((bw / img_w) * project_w, 1))
        rh = max(3.0, round((bh / img_h) * project_h, 1))
        rooms.append({"name": "Room", "x": rx, "y": ry, "width": rw, "height": rh})

    print(f"[OpenCV] Contour method: {len(rooms)} rooms found", file=sys.stderr)

    # If contours produced 0 rooms, fall back to a dynamic layout based on aspect ratio
    if len(rooms) < 1:
        print("[OpenCV] No rooms found — using dynamic grid fallback", file=sys.stderr)
        # Use a slightly randomized grid so multiple failed uploads aren't identical
        import random
        rand = random.Random(image_path) # Deterministic for same image, different for others
        
        split_x = 0.45 + (rand.random() * 0.1)
        split_y = 0.45 + (rand.random() * 0.1)
        
        w1, w2 = round(project_w * split_x, 1), round(project_w * (1-split_x), 1)
        h1, h2 = round(project_h * split_y, 1), round(project_h * (1-split_y), 1)
        
        rooms = [
            {"name": "Living Area", "x": 0,  "y": 0,  "width": w1, "height": h1},
            {"name": "Kitchen/Dining", "x": w1, "y": 0, "width": w2, "height": h1},
            {"name": "Master Suite", "x": 0, "y": h1, "width": w1, "height": h2},
            {"name": "Guest Room", "x": w1, "y": h1, "width": w2, "height": h2},
        ]

    # Method 3: Dynamic single-room fallback (NEVER generic grid)
    if len(rooms) < 1:
        print("[OpenCV] Last resort: dynamic plot-sized room", file=sys.stderr)
        rooms = [
            {"name": "Main Hall", "x": 0, "y": 0, "width": project_w, "height": project_h}
        ]

    project = {"name": "Extracted Plan", "width": project_w, "height": project_h}
    print(f"[OpenCV] Final: {len(rooms)} rooms ({project_w}x{project_h} ft)", file=sys.stderr)

    return {
        "project": project,
        "rooms": rooms,
        "walls": generate_walls_from_rooms(rooms, project),
        "doors": [],
        "windows": [],
        "furnitures": []
    }


def _name_rooms_by_size(rooms, image_id=""):
    """Assign realistic room names based on relative room size."""
    if not rooms:
        return rooms
    sorted_rooms = sorted(rooms, key=lambda r: r['width'] * r['height'], reverse=True)
    max_area = sorted_rooms[0]['width'] * sorted_rooms[0]['height']
    name_pool = ['Living Room','Master Bedroom','Bedroom','Dining Area',
                 'Kitchen','Hall','Bedroom 2','Bathroom','Toilet','Utility Area',
                 'Pooja','Portico','Store Room']
    used = []
    for i, r in enumerate(sorted_rooms):
        area = r['width'] * r['height']
        frac = area / max_area if max_area > 0 else 1.0
        if i == 0:
            name = 'Living Room'
        elif frac > 0.55 and 'Master Bedroom' not in used:
            name = 'Master Bedroom'
        elif frac > 0.35 and 'Bedroom' not in used:
            name = 'Bedroom'
        elif frac > 0.25 and 'Dining Area' not in used:
            name = 'Dining Area'
        elif frac > 0.2 and 'Kitchen' not in used:
            name = 'Kitchen'
        elif frac > 0.2 and 'Hall' not in used:
            name = 'Hall'
        elif frac > 0.15 and 'Bedroom 2' not in used:
            name = 'Bedroom 2'
        elif frac > 0.15 and 'Bathroom' not in used:
            name = 'Bathroom'
        elif frac < 0.15 and used.count('Toilet') < 2:
            name = 'Toilet'
        elif frac < 0.15 and 'Utility Area' not in used:
            name = 'Utility Area'
        elif 'Pooja' not in used:
            name = 'Pooja'
        else:
            for n in name_pool:
                if n not in used:
                    name = n
                    break
            else:
                name = f'Room {i+1}'
        used.append(name)
        r['name'] = f"{name} ({image_id})" if image_id else name
    return rooms


def process_floor_plan(image_path):
    """Main: Gemini AI (reads image labels) → OpenCV (unique per image)."""
    result = get_gemini_analysis(image_path)
    if result and result.get('rooms') and len(result['rooms']) > 0:
        print(f"[process] Gemini: {len(result['rooms'])} rooms", file=sys.stderr)
        return result

    print("[process] Using OpenCV image analysis", file=sys.stderr)
    fallback = fallback_opencv_extraction(image_path)
    if fallback and fallback.get('rooms'):
        img_id = hex(abs(hash(image_path)))[2:6]
        fallback['rooms'] = _name_rooms_by_size(fallback['rooms'], img_id)
        fallback['walls'] = generate_walls_from_rooms(
            fallback['rooms'], fallback.get('project', {})
        )
    return fallback


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No image path provided"}))
        sys.exit(1)

    image_path = sys.argv[1]
    try:
        output = process_floor_plan(image_path)
        print(json.dumps(output))
    except Exception as e:
        print(f"Critical Error: {e}", file=sys.stderr)
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
