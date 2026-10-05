import os
import glob
import subprocess
import json
import time

def run_regression():
    upload_dir = "uploads"
    images = glob.glob(os.path.join(upload_dir, "*.png")) + \
             glob.glob(os.path.join(upload_dir, "*.jpg")) + \
             glob.glob(os.path.join(upload_dir, "*.jpeg"))
             
    print(f"Found {len(images)} images for regression testing.")
    
    results = []
    
    for img_path in images:
        print(f"\n--- Testing {img_path} ---")
        out_dir = f"cv_debug_output_reg_{os.path.basename(img_path).split('.')[0]}"
        os.makedirs(out_dir, exist_ok=True)
        
        start_t = time.time()
        # Run in a subprocess to prevent crashes from halting the suite
        try:
            res = subprocess.run(["python", "cv_engine.py", img_path, out_dir], 
                                 capture_output=True, text=True, timeout=120)
            if res.returncode != 0:
                print(f"[FAIL] cv_engine crashed with return code {res.returncode}")
                # We can still check if it generated a json before crashing
        except subprocess.TimeoutExpired:
            print(f"[TIMEOUT] cv_engine took longer than 120s for {img_path}")
            
        dur = time.time() - start_t
        
        json_path = os.path.join(out_dir, "canonical_output.json")
        metrics = {
            "image": os.path.basename(img_path),
            "duration_sec": round(dur, 2)
        }
        
        if os.path.exists(json_path):
            try:
                with open(json_path, "r") as f:
                    d = json.load(f)
                    
                metrics["1_source_dims"] = f"{d.get('source', {}).get('resolution', {}).get('w', '?')}x{d.get('source', {}).get('resolution', {}).get('h', '?')}"
                
                # footprint is bounding box of all exterior walls or room bounds
                metrics["2_arch_region"] = "Extracted"
                metrics["3_boundary_polygon"] = len(d.get('building', {}).get('footprint_polygon', [])) > 0
                metrics["4_phys_dims"] = "x".join([str(round(d.get('building', {}).get('dimensions', {}).get(k, 0),1)) for k in ['w','h']])
                
                walls = d.get('walls', [])
                metrics["5_ext_walls"] = sum(1 for w in walls if w.get("is_exterior"))
                metrics["6_int_walls"] = sum(1 for w in walls if not w.get("is_exterior"))
                
                rooms = d.get('rooms', [])
                metrics["7_rooms"] = len(rooms)
                metrics["8_named_rooms"] = sum(1 for r in rooms if r.get('label') != "Unknown")
                metrics["9_unknown_rooms"] = sum(1 for r in rooms if r.get('label') == "Unknown")
                
                metrics["10_doors"] = len(d.get('doors', []))
                metrics["11_windows"] = len(d.get('windows', []))
                metrics["12_unknown_openings"] = len(d.get('unknown_openings', []))
                metrics["13_stairs"] = len(d.get('stairs', []))
                
                metrics["14_orientation"] = d.get('source', {}).get('orientation', 'None')
                metrics["15_json_valid"] = True
                
                val = d.get('validation', {})
                metrics["16_recon_2d_valid"] = val.get("overall_geometry_valid", False)
                metrics["17_iou_wall"] = val.get("wall_iou", 0)
                metrics["17_iou_room"] = val.get("room_iou", 0)
                metrics["17_iou_boundary"] = val.get("outer_boundary_iou", 0)
                
                metrics["18_acct_valid"] = val.get("gates", {}).get("object_accounting_valid", False)
                
                metrics["19_strict_status"] = "PASS" if d.get('error') != "STRICT_VALIDATION_FAILED" else "FAIL"
                
                if d.get('error') == "STRICT_VALIDATION_FAILED":
                    gates = val.get("gates", {})
                    failed_gates = [k for k, v in gates.items() if not v]
                    metrics["failure_reasons"] = ", ".join(failed_gates)
                else:
                    metrics["failure_reasons"] = "None"
                    
            except Exception as e:
                metrics["15_json_valid"] = False
                metrics["error"] = f"JSON parsing error: {e}"
        else:
            metrics["15_json_valid"] = False
            metrics["error"] = "canonical_output.json not generated"
            
        results.append(metrics)
        print(metrics)
        
    with open("regression_report.json", "w") as f:
        json.dump(results, f, indent=2)
        
    print("\nRegression suite completed.")

if __name__ == "__main__":
    run_regression()
