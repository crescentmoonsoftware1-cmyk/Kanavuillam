import sys
import json
import os
# Prevent OpenCV/PyTorch from using too many threads and crashing with Unknown C++ exception on Windows Node spawn
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["VECLIB_MAXIMUM_THREADS"] = "1"
os.environ["NUMEXPR_NUM_THREADS"] = "1"

from cv_engine import extract_geometry

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No image path provided"}))
        sys.exit(1)
        
    image_path = sys.argv[1]
    
    try:
        canonical_json = extract_geometry(image_path, out_dir=None)
        
        print(json.dumps(canonical_json))
        
    except Exception as e:
        import traceback
        error_msg = traceback.format_exc()
        with open("debug_error.txt", "w") as f:
            f.write(error_msg)
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
