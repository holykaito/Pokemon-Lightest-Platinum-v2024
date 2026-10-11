"""Create a read-only catalogue from the supplied Essentials PBS and sprites."""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBS = ROOT / "PBS"
SPRITES = ROOT / "Sprite"
OUT = ROOT / "dist"


def sections(path):
    current = None
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line.startswith("[") and "]" in line:
            if current is not None:
                yield current
            current = {"_id": line[1:line.index("]")].strip()}
        elif current is not None and "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            current[key.strip()] = value.strip()
    if current is not None:
        yield current


def load(pattern):
    records = {}
    for file in sorted(PBS.glob(pattern)):
        for row in sections(file):
            key = row.pop("_id")
            # Keep every field from the latest PBS section, including custom ones.
            records.setdefault(key, {}).update(row)
    return records


def parts(value):
    return [x.strip() for x in value.split(",") if x.strip()]


def move_pairs(value):
    a = parts(value)
    return [{"level": a[i], "id": a[i+1]} for i in range(0, len(a) - 1, 2)]


def evolutions(value):
    a = parts(value)
    return [{"to": a[i], "method": a[i+1], "value": a[i+2]} for i in range(0, len(a) - 2, 3)]


def main(pbs_path=None, sprite_path=None):
    global PBS, SPRITES
    PBS = Path(pbs_path) if pbs_path else ROOT / "PBS"
    SPRITES = Path(sprite_path) if sprite_path else ROOT / "Sprite"
    if not PBS.is_dir() or not SPRITES.is_dir():
        raise FileNotFoundError("Cần đặt thư mục PBS và Sprite bên cạnh START_WINDOWS.bat")
    forms = load("pokemon_forms*.txt")
    base = {}
    for path in sorted(PBS.glob("pokemon*.txt")):
        if path.name.startswith("pokemon_forms"):
            continue
        for item in sections(path):
            key = item.pop("_id")
            base.setdefault(key, {}).update(item)
    abilities = load("abilities*.txt")
    moves = load("moves*.txt")
    innate = load("innate_sets.txt")
    pngs = {f.stem.upper(): f.name for f in SPRITES.glob("*.png")}

    def as_record(id_, raw, form=None):
        species = id_.split(",")[0]
        number = id_.split(",")[1] if "," in id_ else "0"
        key = species if form is None else f"{species}_{number}"
        src = raw if form is None else {**base.get(species, {}), **raw}
        stats = [int(n) if n.strip().isdigit() else 0 for n in parts(src.get("BaseStats", ""))]
        evos = evolutions(src.get("Evolutions", ""))
        innate_row = innate.get(key, innate.get(species, {}))
        return {
            "id": key, "species": species, "form": number, "name": src.get("Name", species),
            "formName": raw.get("FormName", "") if form is not None else "",
            "types": parts(src.get("Types", "")), "stats": stats,
            "abilities": parts(src.get("Abilities", "")),
            "hidden": parts(src.get("HiddenAbilities", "")),
            "innates": parts(innate_row.get("Innates", src.get("Innates", ""))),
            "category": src.get("Category", ""), "description": src.get("Pokedex", ""),
            "generation": src.get("Generation", ""),
            "height": src.get("Height", ""), "weight": src.get("Weight", ""),
            "sprite": pngs.get(key, pngs.get(species) if form is not None else None),
            "moves": move_pairs(src.get("Moves", "")),
            "tutor": parts(src.get("TutorMoves", "")),
            "egg": parts(src.get("EggMoves", "")),
            "evolutions": evos,
            "fields": src,
            "isForm": form is not None,
        }

    records = [as_record(k, v) for k, v in base.items()]
    records += [as_record(k, v, True) for k, v in forms.items() if k.split(",")[0] in base]
    sprite_out = OUT / "sprites"
    sprite_out.mkdir(parents=True, exist_ok=True)
    used = {row["sprite"] for row in records if row["sprite"]}
    for name in used:
        shutil.copyfile(SPRITES / name, sprite_out / name)
    ability_info = {k: {"name": v.get("Name", k), "description": v.get("Description", "")} for k, v in abilities.items()}
    move_info = {k: {"name": v.get("Name", k), "type": v.get("Type", ""), "category": v.get("Category", ""), "power": v.get("Power", ""), "description": v.get("Description", "")} for k, v in moves.items()}
    (OUT / "data.json").write_text(json.dumps({"pokemon": records, "abilities": ability_info, "moves": move_info}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(base)} species, {len(records)-len(base)} forms, {len(used)} sprites; {sum(bool(r['innates']) for r in records)} innate entries")


if __name__ == "__main__":
    main()
