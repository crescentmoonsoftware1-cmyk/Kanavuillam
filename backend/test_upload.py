import requests
import json

url = "https://kanavuillam-production.up.railway.app/api/upload"

# Create a dummy image
with open("dummy.jpg", "wb") as f:
    f.write(b"\xff\xd8\xff\xe0" + b"\x00" * 1000)

files = {
    "ground_plan": ("dummy.jpg", open("dummy.jpg", "rb"), "image/jpeg")
}
data = {
    "name": "Test Project"
}

print("Uploading to Railway...")
try:
    res = requests.post(url, files=files, data=data)
    print("Status code:", res.status_code)
    print("Response:", res.text[:500])
except Exception as e:
    print("Error:", e)
