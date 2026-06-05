import os
import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace .withOpacity(x) with .withValues(alpha: x)
    # Be careful with nested parentheses. Simple regex usually works if opacity values are simple (e.g. 0.5, 0.5 + var)
    # We will just replace .withOpacity( followed by whatever up to the balancing parenthesis.
    
    # Actually, a simpler regex for most common cases:
    # .withOpacity(0.5) -> .withValues(alpha: 0.5)
    
    def replacer(match):
        val = match.group(1)
        return f".withValues(alpha: {val})"
        
    # We can match .withOpacity( ... ) where ... doesn't contain closing parens.
    # In dart, it's mostly .withOpacity(0.5) or .withOpacity(opacity)
    new_content = re.sub(r'\.withOpacity\(([^)]+)\)', replacer, content)

    # Let's also fix camel_case_types in lib/screens/web_stub.dart
    if filepath.endswith('web_stub.dart'):
        new_content = new_content.replace('class window', 'class Window')
        new_content = new_content.replace('class document', 'class Document')
        new_content = new_content.replace('class platformViewRegistry', 'class PlatformViewRegistry')
        new_content = new_content.replace('final window = Window();', 'final Window window = Window();')
        new_content = new_content.replace('final document = Document();', 'final Document document = Document();')
        new_content = new_content.replace('final platformViewRegistry = PlatformViewRegistry();', 'final PlatformViewRegistry platformViewRegistry = PlatformViewRegistry();')

    # Remove unused variables directly by commenting them out or fixing them.
    # We'll just do manual fixes for the ones we saw, if they match
    if filepath.endswith('upload_screen.dart'):
        new_content = re.sub(r'final safeTop = MediaQuery.*?;', '', new_content)
    if filepath.endswith('viewer_screen.dart'):
        new_content = re.sub(r'bool _showVastuAnalysis = false;', '', new_content)
        new_content = re.sub(r'final surface = Theme.*?;', '', new_content)
        new_content = re.sub(r'void _editRooms.*?\{.*?\n.*?\}', '', new_content, flags=re.DOTALL)
    if filepath.endswith('pdf_service.dart'):
        new_content = re.sub(r'final bgBlue = .*?;', '', new_content)
        new_content = re.sub(r'final bgOrange = .*?;', '', new_content)
        new_content = re.sub(r'final columns = .*?;', '', new_content)
    if filepath.endswith('material_search_widget.dart'):
        new_content = re.sub(r'static const _bg = .*?;', '', new_content)
        new_content = re.sub(r'final mins = .*?;', '', new_content)
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed {filepath}")

for root, dirs, files in os.walk('.'):
    for f in files:
        if f.endswith('.dart'):
            fix_file(os.path.join(root, f))
