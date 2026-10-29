"""Make labeled QA contact sheets from this run's actual terrain screenshots."""
from pathlib import Path
import json
import sys
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent / "artifacts"
matrix = "--matrix" in sys.argv
debug = "--debug" in sys.argv
report = json.loads((root / ("dune_matrix.json" if matrix else "preview_report.json")).read_text(encoding="utf-8"))
records = [row for row in report["captures"] if ("_debug_" in row["name"]) == debug]
assert report["completed"] and len(records) == (33 if debug else (45 if matrix else 39))
for page in range((len(records) + 11) // 12):
    rows = records[page * 12:(page + 1) * 12]
    sheet = Image.new("RGB", (1440, ((len(rows) + 2) // 3) * 294), "#161b20")
    draw = ImageDraw.Draw(sheet)
    for index, row in enumerate(rows):
        image = Image.open(root / (row["name"] + ".png")).convert("RGB")
        image.thumbnail((480, 270))
        x, y = (index % 3) * 480, (index // 3) * 294
        sheet.paste(image, (x, y))
        draw.text((x + 8, y + 274), row["name"], fill="white")
    target = root / f"{'debug' if debug else ('matrix' if matrix else 'review')}_contact_{page + 1}.jpg"
    sheet.save(target, quality=92)
    print(target)
