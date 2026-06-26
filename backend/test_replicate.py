import os
import requests
import json

from dotenv import load_dotenv

load_dotenv()

token = os.getenv("REPLICATE_API_TOKEN")
if not token:
    print("No token found in .env")
    exit(1)
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "Prefer": "wait"
}
data = {
    "input": {
        "prompt": "a house",
        "aspect_ratio": "4:3",
        "output_format": "png",
        "go_fast": True
    }
}

res = requests.post("https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions", headers=headers, json=data)
print(res.status_code)
print(json.dumps(res.json(), indent=2))
