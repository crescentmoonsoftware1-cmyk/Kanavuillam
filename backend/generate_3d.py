import os
import vertexai
from vertexai.preview.vision_models import ImageGenerationModel

# 1. Download panna JSON file-oda path-ai inga set pandrom (same folder-la iruntha ipadiye vidalam)
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "credentials.json"

# 2. Unga exact Project ID (file name-la irunthu eduthathu)
PROJECT_ID = "gen-lang-client-0595961992" 
LOCATION = "us-central1"

print("Connecting to Google Cloud...")
vertexai.init(project=PROJECT_ID, location=LOCATION)

# 3. Latest Imagen 3 model-ai load pandrom
print("Loading Imagen 3 model...")
model = ImageGenerationModel.from_pretrained("imagen-3.0-generate-002")

# 4. Namma munnadi uruvakkuna 3D House Prompt (Itha neenga unga thevaikku maathikalam)
prompt = """
A high-definition, photorealistic, elevated 3D architectural visualization of a single-story modern residential house, built precisely according to a 30'x40' 2D plan layout. Model the entire house structure on a concrete plinth. The exterior is shown from a North-East elevated perspective, looking into the cutaway interior. Detailed realistic lighting, smooth exterior walls, tiled floors inside, and a parked car in the portico.
"""

print("Generating 3D Visualization... (It takes 10-20 seconds)")

# 5. Image generate pandrom
images = model.generate_images(
    prompt=prompt,
    number_of_images=1,       
    aspect_ratio="16:9",      # Widescreen view
    guidance_scale=15         
)

# 6. Image-ai save pandrom
output_filename = "3d_house_render.png"
images[0].save(location=output_filename)

print(f"🎉 Success! Image saved as {output_filename}")