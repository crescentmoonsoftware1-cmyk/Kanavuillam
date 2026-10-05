import re

def parse_architectural_dimension(text):
    """
    Parses a string representing a room dimension (e.g. 16'x24' or 16x24)
    and returns the normalized width and height in feet, along with the parse status.
    
    If the format is malformed or highly ambiguous (e.g., 3.0x76.0), it is marked UNCERTAIN.
    """
    t_clean = text.lower().strip()
    
    # Extract the portion that looks like a dimension first: e.g., 16'x24' or 16x24
    # We define a dim_part that handles either:
    # - a number optionally followed by feet and inches
    # - a number optionally followed by just inches
    dim_part = r'(\d+(?:\.\d+)?\s*(?:(?:ft|\')\s*(?:-?\s*\d+(?:\.\d+)?\s*(?:\"|in)?)?|(?:\"|in))?)'
    dim_match = re.search(dim_part + r'\s*(?:x|by)\s*' + dim_part, t_clean)
    
    if not dim_match:
        return {
            "raw_text": text,
            "normalized_ft": None,
            "parse_status": "UNCERTAIN_FORMAT"
        }
        
    parts = [dim_match.group(1), dim_match.group(2)]
        
    def parse_single_dim(dim_str):
        dim_str = dim_str.strip()
        
        # Regex to match feet and optional inches:
        # e.g., 7', 7'6", 7'-6", 7' 6", 7.5', 7.50', 76
        # Matches: (feet)(unit_ft)?(separator)?(inches)?(unit_in)?
        # Let's be strict:
        # 1. Matches digits (with optional decimals)
        # 2. Optional feet marker (', ft)
        # 3. Optional hyphen or space
        # 4. Optional inches digits
        # 5. Optional inch marker (", in)
        
        m = re.match(r'^(\d+(?:\.\d+)?)\s*(?:(?:ft|\')\s*(?:-?\s*(\d+(?:\.\d+)?)\s*(?:\"|in)?)?)?$', dim_str)
        if m:
            feet_val = float(m.group(1))
            inches_val = float(m.group(2)) if m.group(2) else 0.0
            
            # If there's no feet marker and no inches, it's just a raw number (e.g. "16")
            # If the raw number is > 50, it's highly suspicious (e.g. "76" instead of "7'6")
            has_explicit_unit = "'" in dim_str or "ft" in dim_str or '"' in dim_str or "in" in dim_str
            if not has_explicit_unit and feet_val > 50:
                return None, "SUSPICIOUS_LARGE_RAW_NUMBER"
                
            return feet_val + (inches_val / 12.0), "VALID"
            
        # Fallback for purely inches (e.g. 84")
        m_in = re.match(r'^(\d+(?:\.\d+)?)\s*(?:\"|in)$', dim_str)
        if m_in:
            return float(m_in.group(1)) / 12.0, "VALID"
            
        return None, "INVALID_FORMAT"

    w_val, w_status = parse_single_dim(parts[0])
    h_val, h_status = parse_single_dim(parts[1])
    
    if w_status == "VALID" and h_status == "VALID":
        return {
            "raw_text": text,
            "normalized_ft": {"w": round(w_val, 2), "h": round(h_val, 2)},
            "parse_status": "VALID"
        }
    else:
        return {
            "raw_text": text,
            "normalized_ft": None,
            "parse_status": "UNCERTAIN"
        }
