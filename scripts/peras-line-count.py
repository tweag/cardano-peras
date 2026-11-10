#!/usr/bin/env python3
"""Count lines contributed to Peras across several GitHub repositories.

Usage: peras-line-count.py [-v | -vv] [--depth N] [--colored-bar]
                           [--bar-width N] [--cache-dir DIR]
e.g. from the root of the repo:

GITHUB_TOKEN=<TOKEN> python3 peras-line-count.py -v --depth=6 --colored-bar

Prints a tree of groups of files (see below) with two line counts for each:

* Merged lines: the number of lines currently present on the repository's
  default branch (e.g. `main` or `master`) whose *last* modification, as
  reported by `git blame`, comes from a "qualifying commit". A line edited
  several times is counted at most once, and only if its latest edit qualifies.
  Whitespace-only changes do not count as modifications, nor do the commits
  listed in the repository's `.git-blame-ignore-revs` file at the branch tip
  (typically bulk reformattings, which GitHub's blame view skips too):
  `git blame` attributes the lines they touched to earlier changes.
  A commit on the default branch qualifies if its GitHub author is in AUTHORS
  and its first message line, or the title or a label of one of its associated
  PRs, contains at least one of KEYWORDS (case-insensitive substring match).

* Open PR lines: the sum of *added* lines (deletions are ignored) of all open
  PRs (drafts included, any author) of REPOS whose title or one of whose
  labels contains at least one of KEYWORDS (case-insensitive substring match),
  except those in EXCLUDED_PRS. Also counts the open PRs in EXTRA_PRS, from any
  repository and whatever their title and labels (merged or closed ones are
  reported in a warning, and not counted). Additions are as reported by
  GitHub, i.e. relative to the merge base with the PR's target branch: if that
  branch was rewritten (e.g. rebased) since the PR branched off it, the stale
  copies of its commits that the PR still contains are counted too.

Both counts only include lines in files whose path ends with one of
FILE_EXTENSIONS (case-insensitive); an empty FILE_EXTENSIONS counts all files.

Tree (--depth N, default 0): the root, `Total`, has one child per repository
in REPOS or of a PR in EXTRA_PRS, shown even without any counted line. With
N > 0, each repository has its folders as descendants, down to those made of
the first N directory components of a file's path: these are leaves, counting
all the files below them. Files nested less than N folders deep are counted in
a `*` leaf of their own folder, which only counts the files directly inside
it. E.g. with N = 2:

    Total
    └── IntersectMBO/ouroboros-consensus
        ├── *                       files at the root of the repository
        ├── docs/
        │   ├── *                   files directly in docs/
        │   └── website/            all the files below docs/website/
        └── ouroboros-consensus/
            └── src/                all the files below ouroboros-consensus/src/

The counts of a node are thus the sums of its children's. Nodes without any
counted line are omitted (except repositories), and children are sorted by
name. Folders are taken from the file's path at the branch tip (merged lines)
or in the PR (open PR lines).

Each line shows the tree drawing, then the node's name padded to the longest
one, so that what follows is indented like the node in the tree (4 columns per
level), then its merged lines (in green), open PR lines (in blue) and their sum.
With --colored-bar, a bar of --bar-width columns (default: BAR_WIDTH) is drawn
between the name and the counts, showing the node's share of the grand total
of lines: its merged lines as green squares, then its open PR lines as blue
squares, then grey squares up to the bar's width. Each number of green or blue
squares is rounded to the nearest integer, but is never 0 for a non-zero
number of lines; when this makes the bar one square too long, the longer of
its green and blue parts is shortened.

The tree goes to stdout (with ANSI color codes, even when redirected) and logs
go to stderr: only warnings by default; -v adds progress (current step, counts
per author and repository, selected PRs); -vv also tells why each commit and
open PR is selected (✅) or discarded (❌), and how many lines each blamed file
contributes (❌ if none).

Caveats:
* GitHub attributes a commit to a user only through the commit's *author*
  email being linked to that GitHub account; co-authors and committers are
  not considered, and commits made with an unlinked email are missed.
* KEYWORDS are plain substrings, so they also match inside longer words.
* Only the first 5 PRs associated with a commit, and the first 100 labels of
  each PR, are checked for KEYWORDS.
* Merged lines: binary files are skipped; every other file matching
  FILE_EXTENSIONS is blamed line by line (generated files, lock files, etc.
  are counted like any other text file unless excluded by FILE_EXTENSIONS).
* Merged lines: the extension is checked on the file's path at the branch tip,
  so lines whose file was later renamed are judged by the new name.
* Merged lines: lines copied (rather than moved/renamed) from a qualifying
  commit into a file that no qualifying commit touched are not found.
* Open PR lines: the extension is checked on the file's path in the PR, and
  GitHub only exposes the first 3000 changed files of a PR.

Requirements: `git`, and a GitHub token in $GITHUB_TOKEN (or a logged-in `gh`
CLI, whose token is then used). Repositories are cloned (bare, full history)
into the folder given by --cache-dir (default: $PERAS_CACHE_DIR if set, else
/tmp/peras-line-count) on the first run, and only fetched on later runs; they
are cloned again if the folder was deleted, e.g. by a cleanup of /tmp.
"""

import argparse
import dataclasses
import functools
import json
import logging
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

log = logging.getLogger("peras-line-count")
# Marks of selected and discarded items in the logs, also colored with ANSI codes
# for terminals that draw them as plain glyphs rather than as colored emojis.
SELECTED, DISCARDED = "\033[32m✅\033[0m", "\033[31m❌\033[0m"

REPOS = [
    "IntersectMBO/ouroboros-consensus",
    "IntersectMBO/ouroboros-network",
    "IntersectMBO/cardano-ledger",
    "IntersectMBO/cardano-base",
]
# GitHub logins whose commits count if the commit or its PR mentions one of KEYWORDS.
AUTHORS = [
    "tbagrel1",
    "agustinmista",
    "amesgen",
    "niols",
    "geo2a",
    "jasagredo",
    "adithyaov",
    "nbacquey",
    "gdeest",
    "ninioArtillero",
    "ErinvanderVeen",
    "nbloomf",
    "qnikst",
    "prednaz",
]
# A title or label matches if it contains any of these (case-insensitive substring match).
KEYWORDS = ["peras"]
# Only files whose path ends with one of these are counted (e.g. [".hs", ".cabal"]);
# empty means all files.
FILE_EXTENSIONS = [".hs", ".cddl", ".cabal"]
# Open PRs not to count, as (link, reason) pairs: the link is to the PR (or to one
# of its tabs or comments), and the reason is shown in the logs.
EXCLUDED_PRS = [
    # '[Peras ?] Add state machine tests for Peras voting rules'
    ("https://github.com/IntersectMBO/ouroboros-consensus/pull/1751", "way outdated"),
    # '[WIP] Optimize Peras weight calculation'
    ("https://github.com/IntersectMBO/ouroboros-consensus/pull/1613",
     "not planned to be implemented"),
    # '[Peras 8] GSM: new criterion for transitioning to CaughtUp when Peras is enabled'
    ("https://github.com/IntersectMBO/ouroboros-consensus/pull/1783",
     "overseded by Erin and Philip work in "
     "https://github.com/IntersectMBO/ouroboros-consensus/pull/2321 and "
     "https://github.com/IntersectMBO/ouroboros-consensus/pull/2322"),
    # 'Store Peras certs when making boosted blocks immutable'
    ("https://github.com/IntersectMBO/ouroboros-consensus/pull/2266",
     "uses outdated base; superseded by "
     "https://github.com/IntersectMBO/ouroboros-consensus/pull/2293 "
     "'Immutable (aka historical) certificate database'"),
]
# Open PRs to count whatever their title and labels, e.g. from repositories not
# in REPOS, as (link, reason) pairs like EXCLUDED_PRS.
EXTRA_PRS = [
    # 'Account for certificate weight in GDD density computations'
    ("https://github.com/tweag/ouroboros-consensus/pull/37",
     "Can't live on IntersectMBO because it depends on a tweag-hosted base branch"),
]
# Default of --cache-dir.
DEFAULT_CACHE_DIR = os.environ.get("PERAS_CACHE_DIR", "/tmp/peras-line-count")
# Default of --bar-width: number of squares of a full bar.
BAR_WIDTH = 50

# Commits reachable from the default branch whose author is the given GitHub
# user (merge commits included).
# - `first: 100` is the page size, the maximum GitHub allows per request; all
#   pages are fetched by following `endCursor`, so nothing is truncated.
# - `associatedPullRequests(first: 5)` caps the PRs checked for KEYWORDS per
#   commit. A commit on the default branch normally belongs to exactly one PR
#   (the one that merged it); 5 leaves room for e.g. stacked or re-opened PRs.
#   This is NOT paginated: PRs beyond the 5th are ignored.
# - `labels(first: 100)`: the maximum page size, NOT paginated either: labels
#   of a PR beyond the 100th are ignored (PRs have far fewer).
HISTORY_QUERY = """
query($owner: String!, $name: String!, $author: ID!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef {
      name
      target {
        ... on Commit {
          history(first: 100, after: $cursor, author: {id: $author}) {
            pageInfo { hasNextPage endCursor }
            nodes {
              oid
              messageHeadline
              associatedPullRequests(first: 5) {
                nodes { number title labels(first: 100) { nodes { name } } }
              }
            }
          }
        }
      }
    }
  }
}
"""

# All open PRs of the repository (drafts included), with their labels and
# changed files; filtering on the title and labels is done locally, since
# GitHub's search matches whole words only and would miss titles like
# "PerasVoteDB: ...".
# - `first: 100` is the page size, the maximum GitHub allows per request; all
#   pages are fetched by following `endCursor`, so nothing is truncated.
# - `labels(first: 100)`: as in HISTORY_QUERY.
# - `files(first: 100)`: same page size for the changed files of each PR; PRs
#   with more files are completed with PR_FILES_QUERY. GitHub itself only
#   exposes the first 3000 changed files of a PR.
OPEN_PRS_QUERY = """
query($owner: String!, $name: String!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: OPEN, first: 100, after: $cursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number
        title
        labels(first: 100) { nodes { name } }
        files(first: 100) {
          pageInfo { hasNextPage endCursor }
          nodes { path additions }
        }
      }
    }
  }
}
"""

# Remaining changed files of one PR, continuing from `$cursor`; `first: 100` as above.
PR_FILES_QUERY = """
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      files(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes { path additions }
      }
    }
  }
}
"""

# One PR, with the name of its repository as GitHub spells it, and its first
# changed files (`first: 100` as in OPEN_PRS_QUERY, completed with PR_FILES_QUERY).
PR_QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    nameWithOwner
    pullRequest(number: $number) {
      number
      title
      state
      files(first: 100) {
        pageInfo { hasNextPage endCursor }
        nodes { path additions }
      }
    }
  }
}
"""

# Resolves a login to the node ID expected by the `author` filter of HISTORY_QUERY.
USER_QUERY = "query($login: String!) { user(login: $login) { id } }"

# Seconds without any data from GitHub after which a request times out.
HTTP_TIMEOUT = 60
# How many times a request failing with a transient error (see is_transient) is
# retried, after waiting 2, 4, 8, ... seconds.
HTTP_RETRIES = 4


@functools.cache  # Looked up on first use only, so that --help works without a token.
def get_token():
    """Return $GITHUB_TOKEN, falling back to the token of the `gh` CLI."""
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        log.debug("Using the GitHub token in $GITHUB_TOKEN")
        return token
    log.debug("$GITHUB_TOKEN is not set: using the token of the gh CLI")
    try:
        return subprocess.run(
            ["gh", "auth", "token"], capture_output=True, text=True, check=True
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit("No GitHub token: set GITHUB_TOKEN or run `gh auth login`.")


def is_transient(error):
    """True if `error`, raised while querying GitHub, is worth retrying: a timeout,
    or HTTP 502/503/504 (GitHub answers 502 or 504 to queries taking over 10 s)."""
    if isinstance(error, urllib.error.HTTPError):
        return error.code in (502, 503, 504)
    if isinstance(error, urllib.error.URLError):  # E.g. a timeout while connecting.
        error = error.reason
    return isinstance(error, TimeoutError)


def graphql(query, **variables):
    """Run a GitHub GraphQL query and return its `data`.

    Transient errors (see is_transient) are retried up to HTTP_RETRIES times. Exits
    if GitHub reports GraphQL errors; other HTTP errors raise `urllib.error.HTTPError`.
    """
    req = urllib.request.Request(
        "https://api.github.com/graphql",
        data=json.dumps({"query": query, "variables": variables}).encode(),
        headers={"Authorization": f"bearer {get_token()}"},
    )
    retries = 0
    while True:
        try:
            with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
                body = json.load(resp)
            break
        except (urllib.error.URLError, TimeoutError) as e:
            if retries == HTTP_RETRIES or not is_transient(e):
                raise
            retries += 1
            delay = 2**retries
            log.warning("GitHub request failed (%s); retrying in %ds (%d/%d)",
                        e, delay, retries, HTTP_RETRIES)
            time.sleep(delay)
    if "errors" in body:
        sys.exit(f"GraphQL error: {body['errors']}")
    return body["data"]


def mentions_keyword(text):
    """True if `text` contains any of KEYWORDS, ignoring case."""
    text = text.lower()
    return any(k.lower() in text for k in KEYWORDS)


def pr_keyword_match(pr):
    """Which part of `pr` (a GraphQL PullRequest node) contains one of KEYWORDS,
    ignoring case: "title", 'label "<name>"', or None if neither its title nor
    any of its labels does."""
    if mentions_keyword(pr["title"]):
        return "title"
    for label in pr["labels"]["nodes"]:
        if mentions_keyword(label["name"]):
            return f'label "{label["name"]}"'
    return None


def commit_verdict(commit):
    """Whether `commit` (a node of HISTORY_QUERY, by one of AUTHORS) qualifies,
    and why."""
    if mentions_keyword(commit["messageHeadline"]):
        return True, "headline mentions a keyword"
    prs = commit["associatedPullRequests"]["nodes"]
    for pr in prs:
        if match := pr_keyword_match(pr):
            return True, f"{match} of PR #{pr['number']} mentions a keyword"
    numbers = ", ".join(f"#{pr['number']}" for pr in prs) or "none"
    return False, f"no keyword in headline or associated PRs ({numbers})"


def has_counted_extension(path):
    """True if FILE_EXTENSIONS is empty or `path` ends with one of them, ignoring case."""
    path = path.lower()
    return not FILE_EXTENSIONS or any(path.endswith(e.lower()) for e in FILE_EXTENSIONS)


def folder_of(path, depth):
    """Leaf of the tree counting `path` for --depth `depth` (see the module
    docstring), as a path below the repository: the first `depth` directory
    components of `path`, or, if it is nested less deep, its folder followed by
    "/*" ("*" at the repository root)."""
    folders = path.split("/")[:-1]
    if len(folders) >= depth:
        return "/".join(folders[:depth])
    return "/".join(folders + ["*"])


def qualifying_commits(repo, user_ids):
    """Return the default branch name and the set of qualifying commit SHAs.

    `user_ids` maps each login of AUTHORS to its node ID.
    """
    owner, name = repo.split("/")
    branch = None
    shas = set()
    for login, uid in user_ids.items():
        cursor = None
        page = seen = selected = 0
        while True:
            page += 1
            log.debug("Fetching commits by %s (page %d)", login, page)
            data = graphql(
                HISTORY_QUERY, owner=owner, name=name, author=uid, cursor=cursor
            )
            ref = data["repository"]["defaultBranchRef"]
            branch = ref["name"]
            history = ref["target"]["history"]
            for c in history["nodes"]:
                ok, reason = commit_verdict(c)
                log.debug("%s commit %.10s by %s: %r (%s)",
                          f"{SELECTED} Selected" if ok else f"{DISCARDED} Discarded",
                          c["oid"], login,
                          c["messageHeadline"], reason)
                seen += 1
                if ok:
                    selected += 1
                    shas.add(c["oid"])
            if not history["pageInfo"]["hasNextPage"]:
                break
            cursor = history["pageInfo"]["endCursor"]
        # Authors without any commit in this repository are only logged in debug mode.
        log.log(logging.INFO if seen else logging.DEBUG,
                "%s: %d commits on %s, %d selected", login, seen, branch, selected)
    log.info("%d qualifying commits on %s", len(shas), branch)
    return branch, shas


def git(repo_dir, *args, stdin=None):
    """Run a git command in `repo_dir` and return its stdout.

    Git's stderr (e.g. warnings) is logged as a warning; if git fails, raise an
    error that includes it.
    """
    # quotePath=off: print non-ASCII paths verbatim so they can be passed back to git.
    try:
        proc = subprocess.run(
            ["git", "-C", repo_dir, "-c", "core.quotePath=off", *args],
            input=stdin,
            capture_output=True,
            text=True,
            errors="replace",
            check=True,
        )
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            f"`git {shlex.join(args)}` failed in {repo_dir}:\n{e.stderr}"
        ) from e
    if proc.stderr.strip():
        log.warning("git %s: %s", args[0], proc.stderr.strip())
    return proc.stdout


def sync_clone(repo, branch, cache_dir):
    """Clone `repo` into `cache_dir` if needed, update `branch`, return the clone path."""
    path = os.path.join(cache_dir, repo.replace("/", "__") + ".git")
    if not os.path.isdir(path):
        log.info("Cloning %s into %s (full history: this may take a while)", repo, path)
        os.makedirs(cache_dir, exist_ok=True)
        subprocess.run(
            ["git", "clone", "--bare", "--quiet", f"https://github.com/{repo}", path],
            check=True,
        )
    log.info("Fetching %s into %s", branch, path)
    git(path, "fetch", "--quiet", "--force", "origin",
        f"+refs/heads/{branch}:refs/heads/{branch}")
    return path


def candidate_files(path, branch, shas):
    """Return the text files at the tip of `branch` that have one of
    FILE_EXTENSIONS and may contain lines blamed on a qualifying commit.

    This only prunes which files get blamed: a superset is harmless (the blame
    decides what is counted), a missing file loses its lines.
    """
    log.info("Listing the paths touched by the qualifying commits")
    # Paths touched by qualifying commits; merges are diffed against their first parent.
    touched = set(
        git(path, "log", "--no-walk=unsorted", "--diff-merges=first-parent",
            "--format=", "--name-only", "--stdin",
            stdin="\n".join(shas)).split("\n")
    ) - {""}
    log.info("Following later renames of these %d paths in the history of %s",
             len(touched), branch)
    # Follow later renames (oldest first), as `git blame` follows them too.
    for line in git(path, "log", "--reverse", "-M", "--name-status", "--format=",
                    branch).split("\n"):
        if line.startswith("R"):
            _, old, new = line.split("\t")
            if old in touched:
                log.debug("Following rename %s -> %s", old, new)
                touched.add(new)
    # `git grep -I` lists only non-binary files (as "<branch>:<path>").
    text_files = {
        p.removeprefix(f"{branch}:")
        for p in git(path, "grep", "-I", "--name-only", "-e", "", branch).split("\n")
    }
    candidates = {f for f in text_files & touched if f and has_counted_extension(f)}
    log.info("%d candidate files: text files at the tip of %s with a counted "
             "extension, touched by a qualifying commit (maybe under an older name)",
             len(candidates), branch)
    return candidates


# In `git blame --porcelain` output, every line of the file is preceded by a
# header "<sha> <orig-line> <final-line>[ <group-size>]" and is itself prefixed
# by a tab; other metadata lines (author, summary, ...) never start with a SHA.
BLAME_HEADER = re.compile(r"^([0-9a-f]{40}) \d+ \d+")


def blame_ignore_revs(path, branch):
    """Content of the `.git-blame-ignore-revs` file at the root of `branch`'s tip
    ("" if there is none)."""
    name = ".git-blame-ignore-revs"
    if not git(path, "ls-tree", "--name-only", branch, name):
        log.info("No %s: blame only ignores whitespace changes", name)
        return ""
    content = git(path, "show", f"{branch}:{name}")
    revs = [s for line in content.splitlines() if (s := line.split("#", 1)[0].strip())]
    log.info("Blame ignores whitespace changes and the %d commits listed in %s",
             len(revs), name)
    log.debug("Ignored commits: %s", ", ".join(revs))
    return content


def blamed_lines(path, branch, file, shas, ignore_revs):
    """Number of lines of `file` at the tip of `branch` last modified by a commit in
    `shas`, ignoring whitespace changes and the commits listed in the file at path
    `ignore_revs`, and total number of lines of `file`."""
    count = total = 0
    current = None
    # --no-ignore-revs-file drops the lists git would use on its own (the user's
    # blame.ignoreRevsFile setting and, since git 2.98, HEAD:.git-blame-ignore-revs),
    # so that only `ignore_revs` is used, whatever the git version and configuration.
    for line in git(path, "blame", "--porcelain", "-w", "--no-ignore-revs-file",
                    f"--ignore-revs-file={ignore_revs}", branch, "--", file).split("\n"):
        if line.startswith("\t"):
            total += 1
            count += current in shas
        elif m := BLAME_HEADER.match(line):
            current = m.group(1)
    return count, total


def merged_lines(repo, user_ids, depth, cache_dir):
    """Per tree leaf (see folder_of), lines on the default branch whose last edit is
    from a qualifying commit; the repository is cloned into `cache_dir`."""
    counts = Counter()
    branch, shas = qualifying_commits(repo, user_ids)
    if not shas:
        log.info("No qualifying commits: skipping the clone and blame")
        return counts
    path = sync_clone(repo, branch, cache_dir)
    files = sorted(candidate_files(path, branch, shas))
    # `git blame` reads ignored revisions from a file, and the bare clone has no work tree.
    with tempfile.NamedTemporaryFile("w") as ignore_revs:
        ignore_revs.write(blame_ignore_revs(path, branch))
        ignore_revs.flush()
        blame = functools.partial(
            blamed_lines, path, branch, shas=shas, ignore_revs=ignore_revs.name
        )
        log.info("Blaming %d files", len(files))
        step = max(1, len(files) // 10)  # Progress is logged every ~10% of the files.
        with ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
            for i, (f, (n, total)) in enumerate(zip(files, pool.map(blame, files)), 1):
                counts[folder_of(f, depth)] += n
                log.debug("%s Blamed %s: %d of its %d lines are from qualifying commits",
                          SELECTED if n else DISCARDED, f, n, total)
                if i % step == 0 or i == len(files):
                    log.info("Blamed %d/%d files", i, len(files))
    log.info("%d merged lines from qualifying commits", sum(counts.values()))
    return counts


def pr_files(owner, name, pr):
    """All changed files of `pr` (a node of OPEN_PRS_QUERY or PR_QUERY), fetching
    extra pages if needed."""
    files = pr["files"]
    yield from files["nodes"]
    while files["pageInfo"]["hasNextPage"]:
        files = graphql(
            PR_FILES_QUERY, owner=owner, name=name, number=pr["number"],
            cursor=files["pageInfo"]["endCursor"],
        )["repository"]["pullRequest"]["files"]
        yield from files["nodes"]


def add_pr_lines(counts, owner, name, pr, depth):
    """Add to `counts`, per tree leaf (see folder_of), the lines added by `pr` (a node
    of OPEN_PRS_QUERY or PR_QUERY, in the repository `owner`/`name`) in files with
    one of FILE_EXTENSIONS; return a summary of them for the logs."""
    added = counted = skipped = 0
    for f in pr_files(owner, name, pr):
        if has_counted_extension(f["path"]):
            counts[folder_of(f["path"], depth)] += f["additions"]
            added += f["additions"]
            counted += 1
        else:
            skipped += 1
    return f"+{added} lines in {counted} files, {skipped} files skipped by FILE_EXTENSIONS"


# Link to a PR, possibly to one of its tabs (".../pull/2067/files") or comments
# (".../pull/2067#issuecomment-..."), capturing its repository and number.
PR_LINK = re.compile(
    r"https?://(?:www\.)?github\.com/([^/\s]+/[^/\s]+)/pull/(\d+)(?:[/?#]\S*)?"
)


def parse_pr_links(setting, entries):
    """Reason of each PR of `entries`, the value of the setting named `setting`, keyed
    by the repository (in lower case) and number of the PR; exits if an entry is not
    a pair of a link to a PR and a non-empty reason, or if a PR is listed twice."""
    reasons = {}
    for entry in entries:
        m = None
        if (isinstance(entry, (tuple, list)) and len(entry) == 2
                and all(isinstance(item, str) and item.strip() for item in entry)):
            m = PR_LINK.fullmatch(entry[0].strip())
        if not m:
            sys.exit(f"Malformed {setting} entry {entry!r}: expected a pair of a link "
                     "to a PR and a non-empty reason, e.g. ("
                     '"https://github.com/IntersectMBO/ouroboros-consensus/pull/2067", '
                     '"superseded by #2068")')
        key = (m.group(1).lower(), int(m.group(2)))
        if key in reasons:
            sys.exit(f"{setting} lists the PR {key[0]}#{key[1]} twice")
        reasons[key] = entry[1].strip()
    return reasons


def open_pr_lines(repo, depth, excluded, extra):
    """Per tree leaf (see folder_of), sum of added lines (deletions ignored), in files
    with one of FILE_EXTENSIONS, of open PRs whose title or a label mentions one of
    KEYWORDS, except those in `excluded` and in `extra` (see parse_pr_links), the
    latter being counted by extra_pr_lines instead."""
    owner, name = repo.split("/")
    cursor = None
    counts = Counter()
    page = seen = selected = dropped = forced = 0
    log.info("Listing open PRs")
    while True:
        page += 1
        log.debug("Fetching open PRs (page %d)", page)
        prs = graphql(OPEN_PRS_QUERY, owner=owner, name=name, cursor=cursor)[
            "repository"
        ]["pullRequests"]
        for pr in prs["nodes"]:
            seen += 1
            key = (repo.lower(), pr["number"])
            if key in extra:
                forced += 1
                log.debug("Skipping PR #%d %r here: it is counted with EXTRA_PRS",
                          pr["number"], pr["title"])
                continue
            match = pr_keyword_match(pr)
            if not match:
                labels = ", ".join(label["name"] for label in pr["labels"]["nodes"])
                log.debug("%s Discarded PR #%d %r (no keyword in title or labels: %s)",
                          DISCARDED, pr["number"], pr["title"], labels or "none")
                continue
            if key in excluded:
                dropped += 1
                log.info("%s Discarded PR #%d %r (%s mentions a keyword, but the PR is in "
                         "EXCLUDED_PRS: %s)", DISCARDED, pr["number"], pr["title"], match,
                         excluded[key])
                continue
            selected += 1
            lines = add_pr_lines(counts, owner, name, pr, depth)
            log.info("%s Selected PR #%d %r (%s mentions a keyword): %s", SELECTED,
                     pr["number"], pr["title"], match, lines)
        if not prs["pageInfo"]["hasNextPage"]:
            break
        cursor = prs["pageInfo"]["endCursor"]
    log.info("%d of %d open PRs selected (%d more excluded by EXCLUDED_PRS, %d counted "
             "with EXTRA_PRS instead): +%d lines", selected, seen, dropped, forced,
             sum(counts.values()))
    return counts


def extra_pr_lines(extra, depth):
    """Per repository, then per tree leaf (see folder_of), sum of added lines
    (deletions ignored), in files with one of FILE_EXTENSIONS, of the PRs of `extra`
    (see parse_pr_links) that are open, whatever their title and labels; the other
    ones are reported in warnings. Each repository of a PR of `extra` has an entry,
    named as in REPOS if it is there, else as GitHub spells it."""
    names = {repo.lower(): repo for repo in REPOS}
    counts = {}
    selected = 0
    for (repo_key, number), reason in sorted(extra.items()):
        owner, name = repo_key.split("/")
        log.debug("Fetching PR %s#%d", repo_key, number)
        data = graphql(PR_QUERY, owner=owner, name=name, number=number)["repository"]
        repo, pr = names.get(repo_key, data["nameWithOwner"]), data["pullRequest"]
        repo_counts = counts.setdefault(repo, Counter())
        if pr["state"] != "OPEN":
            log.warning("Not counting PR %s#%d %r of EXTRA_PRS (%s): it is %s, not open",
                        repo, number, pr["title"], reason, pr["state"].lower())
            continue
        selected += 1
        lines = add_pr_lines(repo_counts, owner, name, pr, depth)
        log.info("%s Selected PR %s#%d %r (in EXTRA_PRS: %s): %s", SELECTED, repo,
                 number, pr["title"], reason, lines)
    log.info("%d of the %d PRs of EXTRA_PRS counted: +%d lines", selected, len(extra),
             sum(sum(c.values()) for c in counts.values()))
    return counts


# ANSI escape codes coloring merged lines (green), open PR lines (blue) and the
# rest of the bars (dark grey: 238 in the 256-color palette, whose greys range
# from 232, almost black, to 255, almost white).
GREEN, BLUE, GREY, RESET = "\033[32m", "\033[34m", "\033[38;5;238m", "\033[0m"


@dataclasses.dataclass
class Node:
    """A node of the result tree, counting the lines of all the files below it."""

    merged: int = 0
    open_pr: int = 0
    children: dict = dataclasses.field(default_factory=dict)

    def add(self, names, merged=0, open_pr=0):
        """Count `merged` and `open_pr` lines in this node and in each node of the
        path `names` below it, creating the missing ones."""
        self.merged += merged
        self.open_pr += open_pr
        if names:
            child = self.children.setdefault(names[0], Node())
            child.add(names[1:], merged, open_pr)


def leaf_names(leaf):
    """Names of the nodes on the path from a repository to `leaf` (see folder_of),
    those of folders ending with "/"."""
    return [name if name == "*" else f"{name}/" for name in leaf.split("/") if name]


def squares(lines, total, width):
    """Number of squares showing `lines` out of `total` on a bar of `width` squares:
    rounded to the nearest integer, but never 0 if `lines` is not."""
    return max(1, round(lines * width / total)) if lines else 0


def bar(node, total, width):
    """Bar showing the share of `node` in `total` lines (see the module docstring)."""
    green = squares(node.merged, total, width)
    blue = squares(node.open_pr, total, width)
    # Rounding both parts up can make the bar one square too long: shorten the longer.
    if green + blue > width:
        if green >= blue:
            green = width - blue
        else:
            blue = width - green
    grey = width - green - blue
    return f"{GREEN}{'■' * green}{BLUE}{'■' * blue}{GREY}{'■' * grey}{RESET}"


def tree_rows(node, name, branch="", indent=""):
    """Triples of the tree drawing before a node's name, that name, and that node,
    for `node`, named `name`, and its descendants in display order; `branch` is
    drawn before its name and `indent` before the branches of its children."""
    yield branch, name, node
    children = sorted(node.children, key=lambda child: child.rstrip("/"))
    for i, child in enumerate(children):
        last = i == len(children) - 1
        yield from tree_rows(node.children[child], child,
                             indent + ("└── " if last else "├── "),
                             indent + ("    " if last else "│   "))


def tree_lines(root, colored_bar, bar_width):
    """Lines showing the tree of `root` (see the module docstring), with bars of
    `bar_width` squares if `colored_bar`."""
    rows = list(tree_rows(root, "Total"))
    name_width = max(len(name) for _, name, _ in rows)
    total = root.merged + root.open_pr
    for branch, name, node in rows:
        line = f"{branch}{name:<{name_width}}  "
        if colored_bar:
            line += f"{bar(node, total, bar_width)}  "
        yield (f"{line}{GREEN}{node.merged}{RESET} + {BLUE}{node.open_pr}{RESET}"
               f" = {node.merged + node.open_pr}")


def main():
    parser = argparse.ArgumentParser(
        description="Count lines contributed to Peras (see the module docstring)."
    )
    parser.add_argument(
        "--depth", type=int, default=0,
        help="show folders down to N levels below each repository (default: 0)",
    )
    parser.add_argument(
        "--colored-bar", action="store_true",
        help="draw, between the names and the counts, bars showing the share of each "
        "node in the grand total of lines",
    )
    parser.add_argument(
        "--bar-width", type=int, default=BAR_WIDTH, metavar="N",
        help="number of squares of a full bar, with --colored-bar (default: %(default)s)",
    )
    parser.add_argument(
        "--cache-dir", type=os.path.expanduser, default=DEFAULT_CACHE_DIR, metavar="DIR",
        help="folder where repositories are cloned and kept for later runs "
        "(default: $PERAS_CACHE_DIR if set, else /tmp/peras-line-count)",
    )
    parser.add_argument(
        "-v", "--verbose", action="count", default=0,
        help="log progress to stderr (steps, counts, selected PRs); repeat (-vv) to "
        "also log why each commit and open PR is selected or discarded, and the "
        "result of each blamed file",
    )
    args = parser.parse_args()
    depth = args.depth
    if depth < 0:
        parser.error("--depth must be >= 0")
    if args.bar_width < 1:
        parser.error("--bar-width must be >= 1")
    excluded = parse_pr_links("EXCLUDED_PRS", EXCLUDED_PRS)
    extra = parse_pr_links("EXTRA_PRS", EXTRA_PRS)
    if both := excluded.keys() & extra.keys():
        sys.exit("PRs in both EXCLUDED_PRS and EXTRA_PRS: "
                 + ", ".join(f"{repo}#{number}" for repo, number in sorted(both)))
    logging.basicConfig(
        level=[logging.WARNING, logging.INFO, logging.DEBUG][min(args.verbose, 2)],
        format="%(asctime)s %(levelname)-7s %(message)s",
        datefmt="%H:%M:%S",
    )
    log.debug("AUTHORS: %s", AUTHORS)
    log.debug("KEYWORDS: %s, FILE_EXTENSIONS: %s", KEYWORDS, FILE_EXTENSIONS)
    log.debug("EXCLUDED_PRS: %s", EXCLUDED_PRS)
    log.debug("EXTRA_PRS: %s", EXTRA_PRS)

    log.info("Resolving the GitHub IDs of %d authors", len(AUTHORS))
    user_ids = {
        login: graphql(USER_QUERY, login=login)["user"]["id"] for login in AUTHORS
    }
    root = Node()
    if extra:
        # First, so that a wrong entry fails before the long work on REPOS.
        log.info("=== EXTRA_PRS ===")
        for repo, counts in extra_pr_lines(extra, depth).items():
            root.children.setdefault(repo, Node())  # Shown even without any counted line.
            for leaf, n in counts.items():
                if n:
                    root.add([repo, *leaf_names(leaf)], open_pr=n)
    for repo in REPOS:
        log.info("=== %s ===", repo)
        # Possibly already made for EXTRA_PRS; shown even without any counted line.
        root.children.setdefault(repo, Node())
        for leaf, n in merged_lines(repo, user_ids, depth, args.cache_dir).items():
            if n:
                root.add([repo, *leaf_names(leaf)], merged=n)
        for leaf, n in open_pr_lines(repo, depth, excluded, extra).items():
            if n:
                root.add([repo, *leaf_names(leaf)], open_pr=n)

    for line in tree_lines(root, args.colored_bar, args.bar_width):
        print(line)


if __name__ == "__main__":
    main()
