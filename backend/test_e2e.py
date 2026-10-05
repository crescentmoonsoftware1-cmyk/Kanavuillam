import requests
import sys
import json
import time

def test_upload(image_path):
    print("Uploading to backend...")
    url = "http://localhost:3000/api/upload"
    start_time = time.time()
    
    try:
        files = {'ground_plan': open(image_path, 'rb')}
        data = {'floors': '1', 'budget': '50000'}
        
        response = requests.post(url, files=files, data=data)
        elapsed = time.time() - start_time
        print(f"Backend returned in {elapsed:.2f}s with status {response.status_code}")
        
        res_json = response.json()
        with open('run_output.json', 'w') as f:
            json.dump(res_json, f, indent=2)
            
        print("Success! Response captured in run_output.json")
    except Exception as e:
        print(f"Failed to upload: {e}")

if __name__ == "__main__":
    test_upload(sys.argv[1])
