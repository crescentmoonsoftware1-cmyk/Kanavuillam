import os
import sys
import json
import time
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv(override=True)

# This script generates a high-fidelity 3D visualization prompt based on the 2D plan.
# It identifies room layouts and materials to help create the "Premium 3D Design" look.

def generate_3d_visual(image_path, project_meta=None):
    # Use OpenRouter for better prompt generation if available, else Gemini
    api_key = os.getenv("OPENROUTER_API_KEY") or os.getenv("GEMINI_API_KEY")
    if not api_key:
        return {"error": "No API key found"}

    try:
        # Load image for multimodal AI
        import base64
        with open(image_path, "rb") as f:
            image_base64 = base64.b64encode(f.read()).decode("utf-8")

        # Enhanced context if meta is available
        meta_context = ""
        if project_meta:
            meta_context = f"\nPROJECT INFO: This is a {project_meta.get('floors', 1)}-story, {project_meta.get('width')}x{project_meta.get('height')}ft house with {project_meta.get('rooms_count')} rooms."
            if project_meta.get('has_portico'):
                meta_context += " It includes a car parking portico."

        # Dynamic floor description
        floors = project_meta.get('floors', 1) if project_meta else 1
        floor_desc = "single-story (Ground Floor only)" if floors == 1 else f"G+{floors-1}"

        # Prompt to generate architectural and structural prompts
        prompt = f"""
Analyze the uploaded Ground Floor Plan and First Floor Plan carefully {meta_context}.

Generate highly detailed professional prompts for:

1. A SINGLE 3D FRONT ELEVATION view (Premium Modern Style) matching the user's preferred aesthetic.

2. A 3D STRUCTURAL PREVIEW
   - Columns
   - Beams
   - Slabs
   - Staircase
   - Foundation

3. A 2D STRUCTURAL BLUEPRINT
   - Column Grid Layout
   - Beam Layout
   - Structural Labels
   - Dimensions

CRITICAL REQUIREMENTS:

- Analyze BOTH Ground Floor and First Floor.
- Detect actual floor count.
- Detect main entrance location.
- Detect staircase position.
- Detect balcony locations.
- Detect terrace areas.
- Detect parking / portico.
- Detect window alignment.
- Detect building width and shape.

STRICT RULES:

- Do NOT invent rooms.
- Do NOT invent balconies.
- Do NOT change staircase position.
- Do NOT move entrance location.
- Do NOT change floor proportions.
- Do NOT add extra floors.
- Follow uploaded plans exactly.

GROUND FLOOR REQUIREMENTS:

- Match entrance position.
- Match parking / portico.
- Match window placement.
- Match wall projections.

FIRST FLOOR REQUIREMENTS:

- Match balcony positions.
- Match staircase projection.
- Match terrace layout.
- Match window alignment.

ELEVATION STYLE:

Style:
"Photorealistic architectural visualization,
8K resolution,
ultra detailed,
realistic materials,
cinematic lighting"

Camera:
"Professional Straight Front Elevation View"

PREMIUM MODERN:

"STRICTLY {floor_desc} ultra-realistic modern Indian house front elevation. 
Structure: EXACTLY MATCH the front facade of the uploaded floor plan. Do NOT add a portico, parked car, or staircase unless they are explicitly present in the plan.
Materials & Style: Clean off-white/cream exterior walls with light grey accent bands, flat roof with simple modern parapet. Premium modern windows and solid wooden main entrance door.
Settings: WIDE ANGLE SHOT, zoomed out, showing the ENTIRE house from ground to roof with clear margins around it. Bright sunny daytime, clear blue sky, high quality architectural visualization, V-Ray render, sharp focus, 8k"

STRUCTURAL PREVIEW:

"30-degree isometric structural skeleton showing
RCC columns,
RCC beams,
floor slabs,
staircase structure,
foundation footings,
engineering visualization"

STRUCTURAL BLUEPRINT:

"Professional structural drawing,
column grids,
beam labels,
dimension lines,
white technical lines on dark navy blueprint background"

RETURN ONLY JSON:

{{
  "building_analysis": {{
    "floors": "",
    "entrance_position": "",
    "staircase_position": "",
    "balcony_positions": "",
    "portico": ""
  }},

  "elevations": [
    {{
      "style": "Premium Modern",
      "prompt": ""
    }}
  ],

  "structural_preview": {{
    "prompt": ""
  }},

  "structural_blueprint": {{
    "prompt": ""
  }}
}}

The generated elevation must represent the actual house that would be constructed from the uploaded Ground Floor and First Floor plans.
"""

        import requests
        
        if os.getenv("OPENROUTER_API_KEY"):
            # Try multiple models for reliability
            models_to_try = [
                "google/gemini-2.5-flash"
            ]
            
            raw_json = None
            for model in models_to_try:
                try:
                    print(f"[Visualizer] Trying OpenRouter model: {model}", file=sys.stderr)
                    response = requests.post(
                        url="https://openrouter.ai/api/v1/chat/completions",
                        headers={
                            "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
                            "HTTP-Referer": "http://localhost:3000",
                            "X-Title": "Kanavu illam",
                        },
                        data=json.dumps({
                            "model": model,
                            "messages": [
                                {
                                    "role": "user",
                                    "content": [
                                        {"type": "text", "text": prompt},
                                        {
                                            "type": "image_url",
                                            "image_url": {"url": f"data:image/png;base64,{image_base64}"}
                                        }
                                    ]
                                }
                            ],
                            "response_format": { "type": "json_object" }
                        })
                    )
                    if response.status_code == 200:
                        res_data = response.json()
                        raw_json = res_data['choices'][0]['message']['content']
                        print(f"[Visualizer] Success with {model}", file=sys.stderr)
                        break
                    else:
                        print(f"[Visualizer] Model {model} failed: {response.status_code}", file=sys.stderr)
                except Exception as e:
                    print(f"[Visualizer] Error with {model}: {e}", file=sys.stderr)
            
            if not raw_json:
                return {"error": "All OpenRouter models failed"}
        else:
            # Fallback to Gemini
            from google import genai
            from google.genai import types
            client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
            response = client.models.generate_content(
                model='gemini-2.5-flash',
                contents=[
                    prompt,
                    types.Part.from_bytes(data=base64.b64decode(image_base64), mime_type='image/png')
                ],
                config=types.GenerateContentConfig(response_mime_type="application/json")
            )
            raw_json = response.text

        data = json.loads(raw_json)
        
        # Generate Image URLs using Pollinations.ai
        import urllib.parse
        import random
        
        results = {"elevations": [], "structural": {}}
        timestamp = int(time.time() * 1000)

        # 1. Process Elevations
        for i, v in enumerate(data['elevations']):
            seed = random.randint(1, 100000) + timestamp + i
            base_p = f"Professional straight-on front elevation view of a {v['style']} house: {v['prompt']}. photorealistic, 8k, architectural photography, hyper-detailed"
            img_url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(base_p)}?width=1024&height=1024&seed={seed}&nologo=true&model=flux"
            results["elevations"].append({
                "style": v['style'],
                "prompt": v['prompt'],
                "image_url": img_url
            })

        # 2. Process Structural Preview
        sp_seed = random.randint(1, 100000) + timestamp + 50
        sp_prompt = f"Structural skeletal preview of the house: {data['structural_preview']['prompt']}. 30-degree isometric, technical architectural engineering, cyan highlights, 4k"
        results["structural"]["preview_url"] = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(sp_prompt)}?width=1024&height=768&seed={sp_seed}&nologo=true&model=flux"

        # 3. Process Structural Blueprint
        sb_seed = random.randint(1, 100000) + timestamp + 100
        sb_prompt = f"2D Structural Blueprint of the floor plan: {data['structural_blueprint']['prompt']}. Technical drawing, white lines on dark navy background, engineering layout, high precision"
        results["structural"]["blueprint_url"] = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(sb_prompt)}?width=1024&height=1024&seed={sb_seed}&nologo=true&model=flux"

        return {
            "status": "success",
            "variations": results["elevations"], # Keep compatibility with existing code
            "structural": results["structural"]
        }

    except Exception as e:
        return {"error": str(e)}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No image path"}))
        sys.exit(1)

    image_path = sys.argv[1]
    meta = None
    if len(sys.argv) > 2:
        try:
            meta = json.loads(sys.argv[2])
        except:
            pass

    result = generate_3d_visual(image_path, meta)
    print(json.dumps(result))
