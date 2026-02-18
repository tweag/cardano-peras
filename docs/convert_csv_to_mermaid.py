import argparse
import csv
import math

parser = argparse.ArgumentParser(description="Convert roadmap CSV to Mermaid diagram.")
parser.add_argument(
    "--display-progress", choices=["none", "when-set", "always"],
    default="none",
    help="Control progress bar display: 'none' (default) hides all bars, "
         "'when-set' shows bars only for nodes with progress data, "
         "'always' shows bars for all nodes.",
)
parser.add_argument(
    "--display-milestone", action="store_true",
    help="Display the contractual milestone (if non-empty) in the node text.",
)
parser.add_argument(
    "-i", "--input", default="roadmap.csv",
    help="Input CSV file (default: roadmap.csv).",
)
parser.add_argument(
    "-o", "--output", default="roadmap.md",
    help="Output Mermaid file (default: roadmap.md).",
)
args = parser.parse_args()

DISPLAY_PROGRESS = args.display_progress
DISPLAY_MILESTONE = args.display_milestone

INPUT_CSV = args.input
OUTPUT_MMD = args.output

delimiter = ";"


def escape_mermaid_quote(text):
    """Escape double quotes for use inside Mermaid [\"...\"] labels."""
    return text.replace('"', "#quot;")


rows = []
with open(INPUT_CSV, newline="", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f, delimiter=delimiter)

    # normalize fieldnames (remove BOM / spaces)
    reader.fieldnames = [name.strip().lstrip("\ufeff") for name in reader.fieldnames]

    for row in reader:
        rows.append({k.strip(): (v or "").strip() for k, v in row.items()})


BAR_WIDTH = 20


def parse_percent(value):
    """Parse a percentage value (0-100) from a string, return None if invalid."""
    if not value:
        return None
    try:
        v = int(value)
        if 0 <= v <= 100:
            return v
    except ValueError:
        pass
    return None


def compute_bar_chars(last_pct, new_pct):
    """Compute the number of green, blue, and grey characters for the bar.

    Rounding rules:
    - Never round to BAR_WIDTH unless the value is truly 100%.
    - Round the filled total (green + blue) up when fractional part >= 0.5,
      down otherwise.
    - Within that total, round green down and blue up (blue gets priority).
    """
    last = last_pct or 0
    new = new_pct if new_pct is not None else last

    # Exact fractional char counts
    green_exact = BAR_WIDTH * last / 100
    filled_exact = BAR_WIDTH * new / 100

    # Round filled total (green + blue): ceil if frac >= 0.5, else floor
    # But cap at BAR_WIDTH - 1 if not exactly 100%
    if new == 100:
        filled_chars = BAR_WIDTH
    elif filled_exact - math.floor(filled_exact) >= 0.5:
        filled_chars = min(math.ceil(filled_exact), BAR_WIDTH - 1)
    else:
        filled_chars = math.floor(filled_exact)

    # Within filled, blue rounds up, green gets the remainder
    blue_exact = filled_exact - green_exact
    if new == last:
        blue_chars = 0
    else:
        blue_chars = min(math.ceil(blue_exact), filled_chars)
    green_chars = filled_chars - blue_chars

    grey_chars = BAR_WIDTH - filled_chars

    return green_chars, blue_chars, grey_chars


def progress_bar_html(last_pct, new_pct):
    """Generate a colored Unicode progress bar using HTML spans for Mermaid.

    - Green '█' for existing progress (last_pct).
    - Blue '▓' for new progress delta (new_pct - last_pct).
    - Grey '░' for remaining.
    """
    last = last_pct or 0
    new = new_pct if new_pct is not None else last

    green_chars, blue_chars, grey_chars = compute_bar_chars(last_pct, new_pct)

    display_pct = new if new_pct is not None else last

    parts = []
    if green_chars > 0:
        parts.append(f'<span style="color:#4caf50">{"█" * green_chars}</span>')
    if blue_chars > 0:
        parts.append(f'<span style="color:#2196f3">{"▓" * blue_chars}</span>')
    if grey_chars > 0:
        parts.append(f'<span style="color:#ccc">{"░" * grey_chars}</span>')
    parts.append(f" {display_pct}%")

    return "".join(parts)


def make_label(desc, last_pct, new_pct, milestone=""):
    """Build a Mermaid node label, with optional progress bar and milestone."""
    parts = [escape_mermaid_quote(desc)]

    if DISPLAY_MILESTONE and milestone:
        parts.append(f"<br/>\U0001F3AF {escape_mermaid_quote(milestone)}")

    if DISPLAY_PROGRESS != "none":
        has_progress = last_pct is not None or new_pct is not None
        if has_progress or DISPLAY_PROGRESS == "always":
            # Default to 0% when no progress data is provided
            if last_pct is None:
                last_pct = 0
            if new_pct is None:
                new_pct = last_pct
            bar = progress_bar_html(last_pct, new_pct)
            parts.append(f"<br/>{bar}")

    return "".join(parts)


with open(OUTPUT_MMD, "w", encoding="utf-8") as out:
    out.write("```mermaid\ngraph TD\n")

    # --- nodes, styles, and edges ---
    for i, row in enumerate(rows):
        nid = row.get("id", "")
        desc = row.get("description", "")
        deps = row.get("depends_on", "")
        style = row.get("style", "")
        milestone = row.get("contractual_milestone", "")
        last_status = row.get("last_status", "")
        new_status = row.get("new_status", "")

        if not nid:
            continue

        if i > 0:
            out.write("\n")

        last_pct = parse_percent(last_status)
        new_pct = parse_percent(new_status)
        label = make_label(desc or nid, last_pct, new_pct, milestone)

        out.write(f'  {nid}["{label}"]\n')

        if style:
            out.write(f"  style {nid} {style}\n")

        if deps:
            for dep in deps.split(","):
                dep = dep.strip()
                if dep:
                    out.write(f"  {dep} --> {nid}\n")

    out.write("\n```\n")

print(f"Wrote {OUTPUT_MMD}")
