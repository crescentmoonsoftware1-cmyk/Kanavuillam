import sys, json, processor

result = processor.fallback_opencv_extraction('uploads/1777360668592.png')
print('Rooms found:', len(result['rooms']))
for r in result['rooms']:
    print(f"  {r['name']}: x={r['x']}, y={r['y']}, w={r['width']}, h={r['height']}")
print(f"Project: {result['project']}")
print(f"Walls: {len(result['walls'])}")
