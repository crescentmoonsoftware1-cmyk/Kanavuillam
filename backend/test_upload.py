import requests
import sys

ground_path = r"uploads\1778755348006.jpg"
first_path  = r"uploads\1778743383194.jpg"

print(f"Testing upload with ground={ground_path} first={first_path}")
with open(ground_path, 'rb') as gf, open(first_path, 'rb') as ff:
    files = {
        'ground_plan': ('ground.png', gf, 'image/png'),
        'first_plan':  ('first.png',  ff, 'image/png'),
    }
    data = {'name': 'Test Plan'}
    r = requests.post('http://localhost:3000/api/upload', files=files, data=data, timeout=180)

print(f"Status: {r.status_code}")
resp = r.json()
if resp.get('success'):
    model = resp['project']['model_data']
    floors = model.get('floors', {})
    ground_rooms = floors.get('ground', {}).get('rooms', [])
    first_rooms  = floors.get('first', {}).get('rooms', [])
    print(f"Project ID: {resp['project']['id']}")
    print(f"Image URL: {resp['project']['image_url']}")
    print(f"Ground floor rooms: {len(ground_rooms)}")
    for rm in ground_rooms:
        print(f"  {rm['name']}: {rm['width']}x{rm['height']} @ ({rm['x']},{rm['y']})")
    print(f"First floor rooms: {len(first_rooms)}")
    for rm in first_rooms:
        print(f"  {rm['name']}: {rm['width']}x{rm['height']} @ ({rm['x']},{rm['y']})")
else:
    print("Error:", resp)
