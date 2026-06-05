import sys, json, processor

# Test detect + exact template for ground floor image (square ~1:1 ratio)
result = processor.process_floor_plan('uploads/1777360668592.png')
print('Plan type: Ground floor')
print(f"Rooms found: {len(result['rooms'])}")
for r in result['rooms']:
    print(f"  {r['name']}: {r['width']}x{r['height']} @ ({r['x']},{r['y']})")
print()

# Test first floor image (portrait ~0.6 ratio)  
result2 = processor.process_floor_plan('uploads/1777359037475.png')
print('Plan type: First floor')
print(f"Rooms found: {len(result2['rooms'])}")
for r in result2['rooms']:
    print(f"  {r['name']}: {r['width']}x{r['height']} @ ({r['x']},{r['y']})")
