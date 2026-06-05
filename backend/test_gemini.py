import google.generativeai as genai
import os

# Using the key from the environment (I'll hardcode it just for this internal check if needed, 
# but let's try to get it from the file first)
try:
    with open(".env", "r") as f:
        for line in f:
            if "GEMINI_API_KEY=" in line:
                api_key = line.split("=")[1].strip()
                break
except:
    api_key = None

if api_key:
    genai.configure(api_key=api_key)
    try:
        model = genai.GenerativeModel('gemini-1.5-flash-latest')
        print("Success: Model initialized")
        # Try a tiny generation to be sure
        response = model.generate_content("Hello")
        print(f"Response received: {response.text[:10]}...")
    except Exception as e:
        print(f"Error: {e}")
else:
    print("API Key not found")
