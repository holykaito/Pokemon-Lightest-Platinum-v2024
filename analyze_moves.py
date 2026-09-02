import re

# Read the moves.txt file
with open(r'PBS\moves.txt', 'r', encoding='utf-8') as f:
    content = f.read()

# Split by move sections (each starts with [MOVENAME])
moves = content.split('#-------------------------------')

moves_with_secondary_no_effectchance = []

for move_section in moves:
    if not move_section.strip() or '[' not in move_section:
        continue
    
    lines = move_section.strip().split('\n')
    if not lines:
        continue
    
    # Extract move name from first line
    move_name_match = re.search(r'\[(.+?)\]', lines[0])
    if not move_name_match:
        continue
    
    move_id = move_name_match.group(1)
    
    # Find the Name field
    name = None
    function_code = None
    has_effect_chance = False
    
    for line in lines:
        if line.startswith('Name = '):
            name = line.replace('Name = ', '').strip()
        elif line.startswith('FunctionCode = '):
            function_code = line.replace('FunctionCode = ', '').strip()
        elif line.startswith('EffectChance = '):
            has_effect_chance = True
    
    # Check if it's a secondary effect move without EffectChance
    if function_code and not has_effect_chance:
        # Check if it's a secondary effect (Lower* or Raise*)
        if re.search(r'(Lower|Raise)(Target|User)', function_code):
            moves_with_secondary_no_effectchance.append({
                'name': name,
                'function': function_code,
                'move_id': move_id
            })

# Sort by function code for easier reading
moves_with_secondary_no_effectchance.sort(key=lambda x: x['function'])

print(f"Found {len(moves_with_secondary_no_effectchance)} moves with secondary effects but NO EffectChance field:\n")
print("=" * 90)

for move in moves_with_secondary_no_effectchance:
    print(f"{move['name']:<35} | {move['function']:<45}")

print("=" * 90)
