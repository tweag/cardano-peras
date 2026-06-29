import argparse
import re
import csv
from collections import defaultdict, deque

parser = argparse.ArgumentParser(description="Convert Mermaid diagram to roadmap CSV.")
parser.add_argument(
    "-i", "--input", default="roadmap.md",
    help="Input Mermaid file (default: roadmap.md).",
)
parser.add_argument(
    "-o", "--output", default="roadmap.csv",
    help="Output CSV file (default: roadmap.csv).",
)
args = parser.parse_args()

MERMAID_FILE = args.input
OUTPUT_CSV = args.output

node_desc = {}
node_milestone = {}
node_last_status = {}
node_new_status = {}
node_style = defaultdict(list)
deps = defaultdict(set)
all_nodes = set()

# Unicode characters used for progress bars
PROGRESS_CHARS = "█▓░"
MILESTONE_MARKER = "\U0001F3AF"  # 🎯

# Regexes for parsing progress bar from label
# Matches e.g.: <span ...>██████</span><span ...>▓▓</span><span ...>░░░░</span> 80%
progress_re = re.compile(
    r'(?:<span[^>]*>([' + PROGRESS_CHARS + r']+)</span>)+'
    r'\s*(\d+)%'
)
# Simpler fallback: just the block chars and percentage (no spans)
progress_plain_re = re.compile(
    r'([' + PROGRESS_CHARS + r']+)\s*(\d+)%'
)
# Milestone: 🎯 followed by text
milestone_re = re.compile(MILESTONE_MARKER + r'\s*(.+?)(?:<br/>|$)')

edge_re = re.compile(r'^\s*([A-Za-z0-9_]+)\s*-->\s*([A-Za-z0-9_]+)')
# Match both plain [...] and quoted ["..."] labels
label_re = re.compile(r'^\s*([A-Za-z0-9_]+)\["(.*)"\]\s*$')
label_plain_re = re.compile(r'^\s*([A-Za-z0-9_]+)\[([^\]]*)\]\s*$')
style_re = re.compile(r'^\s*style\s+([A-Za-z0-9_]+)\s+(.*)$')


def parse_label(raw_label):
    """Parse a Mermaid node label, extracting description, milestone, and progress.

    Returns (description, milestone, last_status, new_status).
    """
    # Unescape quoted labels (only " needs escaping inside ["..."] labels)
    label = raw_label.replace("#quot;", '"')

    desc = label
    milestone = ""
    last_status = ""
    new_status = ""

    # Extract milestone (🎯 ...)
    m_milestone = milestone_re.search(label)
    if m_milestone:
        milestone = m_milestone.group(1).strip()

    # Extract progress: count █ (green/last) and ▓ (blue/delta) chars,
    # and read the percentage number
    m_progress = progress_re.search(label) or progress_plain_re.search(label)
    if m_progress:
        pct_str = m_progress.group(m_progress.lastindex)
        total_pct = int(pct_str)

        # Gather all block characters from the full match
        full_match = m_progress.group(0)
        green_count = full_match.count("█")
        blue_count = full_match.count("▓")
        grey_count = full_match.count("░")
        total_chars = green_count + blue_count + grey_count

        if total_chars > 0:
            if blue_count > 0:
                # There's a delta: last = green portion, new = total_pct
                last_pct = round(green_count / total_chars * 100)
                new_status = str(total_pct)
                last_status = str(last_pct)
            else:
                # No delta: last_status = total_pct
                last_status = str(total_pct)

    # Clean description: remove milestone and progress bar parts
    # Split on <br/> and keep only the first part (the actual description)
    desc_parts = re.split(r'<br\s*/?>', label)
    desc = desc_parts[0].strip() if desc_parts else label.strip()

    return desc, milestone, last_status, new_status


with open(MERMAID_FILE, encoding="utf-8") as f:
    for line in f:
        line = line.strip()

        # label definitions — try quoted form first, then plain
        m = label_re.match(line)
        if not m:
            m = label_plain_re.match(line)
        if m:
            nid, raw_label = m.groups()
            desc, milestone, last_status, new_status = parse_label(raw_label)
            node_desc[nid] = desc
            node_milestone[nid] = milestone
            node_last_status[nid] = last_status
            node_new_status[nid] = new_status
            all_nodes.add(nid)
            continue

        # edges
        m = edge_re.match(line)
        if m:
            src, dst = m.groups()
            deps[dst].add(src)
            all_nodes.update([src, dst])
            continue

        # styles
        m = style_re.match(line)
        if m:
            nid, style = m.groups()
            node_style[nid].append(style)
            all_nodes.add(nid)
            continue

# ensure all nodes exist
for n in all_nodes:
    node_desc.setdefault(n, n)

# --- topological order ---
in_degree = {n: 0 for n in all_nodes}
for n in all_nodes:
    for d in deps[n]:
        in_degree[n] += 1

queue = deque(sorted([n for n in all_nodes if in_degree[n] == 0]))
topo = []

while queue:
    n = queue.popleft()
    topo.append(n)
    for m in sorted(all_nodes):
        if n in deps[m]:
            in_degree[m] -= 1
            if in_degree[m] == 0:
                queue.append(m)
    queue = deque(sorted(queue))

index = {n: i for i, n in enumerate(topo)}

def max_dep_index(n):
    if not deps[n]:
        return -1
    return max(index[d] for d in deps[n])

sorted_nodes = sorted(all_nodes, key=lambda n: (max_dep_index(n), n))

# --- write CSV ---
with open(OUTPUT_CSV, "w", newline="", encoding="utf-8-sig") as f:
    writer = csv.writer(f, delimiter=";", quoting=csv.QUOTE_MINIMAL)
    writer.writerow(["id", "description", "style", "depends_on", "contractual_milestone", "related_prs","last_status","new_status"])

    for n in sorted_nodes:
        writer.writerow([
            n,
            node_desc[n],
            ",".join(node_style[n]),
            ",".join(sorted(deps[n])),
            node_milestone.get(n, ""),
            "",  # related_prs
            node_last_status.get(n, ""),
            node_new_status.get(n, ""),
        ])

print(f"Wrote {OUTPUT_CSV}")
