"""Root causes that mean the same thing, shared by review.sh (similar causes) and note.sh (seen N times).
Two causes match when they share at least 3 meaningful words and 40 percent of the shorter one's words, so a cause
reworded by another session still counts, and two causes that only open with the same phrase do not.
Usage: python3 -I similar.py count <inbox.md> <cause>   prints '<n> <projects>' for the open rows like <cause>
"""
import re
import sys

STOP = set("the a an and or of to in on for with by from at as is are was were be been it its this that these those not no does did do when then than into only every each any all one two our their they them his her you your which what while after before same also".split())


def words(text):
    out = set()
    for w in re.findall(r"[a-z][a-z'-]+", text.lower()):
        w = w.strip("'-")
        if len(w) < 4 or w in STOP:
            continue
        for suf in ("ing", "ed", "es", "s"):
            if w.endswith(suf) and len(w) - len(suf) >= 4:
                w = w[: -len(suf)]
                break
        out.add(w)
    return out


def similar(a, b):
    shared = len(a & b)
    return shared >= 3 and shared / max(1, min(len(a), len(b))) >= 0.4


def open_rows(path, since=""):
    """(project, cause, words) of the open inbox rows dated since <since>."""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return []
    rows = []
    for line in lines:
        c = [x.strip() for x in line.split("|")]
        if len(c) < 10 or not re.match(r"20\d\d-\d\d-\d\d$", c[1]) or "open" not in c[8] or c[1] < since:
            continue
        rows.append((c[2], c[5], words(c[5])))
    return rows


if __name__ == "__main__" and len(sys.argv) == 4 and sys.argv[1] == "count":
    target = words(sys.argv[3])
    hits = [r for r in open_rows(sys.argv[2]) if r[1] == sys.argv[3] or similar(target, r[2])]
    print(len(hits), ",".join(sorted({r[0] for r in hits})))
