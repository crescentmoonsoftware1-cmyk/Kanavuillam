from dotenv import load_dotenv
load_dotenv()
import os
import sys
from google import genai
from google.genai import types

try:
    client = genai.Client(
        api_key=os.environ.get('GEMINI_API_KEY'),
        http_options={'timeout': 10}
    )
    with open('uploads/1779722357090.png', 'rb') as f:
        image_bytes = f.read()
    
    print("Sending request with 10s timeout...")
    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=[
            types.Part.from_bytes(data=image_bytes, mime_type='image/png'),
            'Describe this image'
        ]
    )
    print("Response received!")
    print(response.text)
except Exception as e:
    print(f"Error: {e}")
