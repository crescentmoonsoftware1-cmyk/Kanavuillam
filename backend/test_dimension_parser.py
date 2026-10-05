from dimension_parser import parse_architectural_dimension

def test_dimensions():
    tests = [
        ("7'x10'", 7.0, 10.0, "VALID"),
        ("7'6\" x 10'0\"", 7.5, 10.0, "VALID"),
        ("7'-6\" x 10'", 7.5, 10.0, "VALID"),
        ("7' 6\" x 10'", 7.5, 10.0, "VALID"),
        ("7.5' x 10'", 7.5, 10.0, "VALID"),
        ("7.50' x 10.0'", 7.5, 10.0, "VALID"),
        ("16'6\" x 24'", 16.5, 24.0, "VALID"),
        ("16'-6\" x 24'", 16.5, 24.0, "VALID"),
        ("29'6\" x 30'", 29.5, 30.0, "VALID"),
        ("29'-6\" x 30'", 29.5, 30.0, "VALID"),
        ("16x24", 16.0, 24.0, "VALID"), # Raw numbers under 50
        ("3.0x76.0", None, None, "UNCERTAIN"), # Suspicious large raw number
        ("3x76", None, None, "UNCERTAIN"), # Suspicious large raw number
        ("100'x200'", 100.0, 200.0, "VALID"), # Large number WITH explicit unit is fine
    ]
    
    passed = 0
    for txt, ew, eh, estatus in tests:
        res = parse_architectural_dimension(txt)
        status = res["parse_status"]
        if status == "VALID":
            w = res["normalized_ft"]["w"]
            h = res["normalized_ft"]["h"]
            if w == ew and h == eh and status == estatus:
                passed += 1
            else:
                print(f"FAILED {txt}: expected {ew}x{eh} {estatus}, got {w}x{h} {status}")
        else:
            if status == estatus:
                passed += 1
            else:
                print(f"FAILED {txt}: expected {estatus}, got {status}")
                
    print(f"Passed {passed}/{len(tests)} tests.")

if __name__ == "__main__":
    test_dimensions()
