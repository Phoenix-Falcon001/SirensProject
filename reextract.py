"""Re-read every stored report with the current extraction rules.

Run once after updating Sirens when the rules changed (for example, place
names are no longer read as people):

    python reextract.py            # show what would change
    python reextract.py --apply    # save the changes

Only the extracted findings (features, people, groups, phones, places) are
rewritten. Report text, dates, photos, analyst decisions and notes are untouched.
"""
from __future__ import annotations

import argparse

from linker import store
from linker.models import Incident


def reextract(extractor, apply: bool = False, db_path=None) -> list[tuple[str, set, set]]:
    """Returns [(incident id, people removed, groups removed)] for changed reports."""
    changed = []
    for old in store.all_incidents(db_path):
        new = Incident(incident_id=old.incident_id, date=old.date, location=old.location,
                       grid=old.grid, narrative=old.narrative, photo=old.photo)
        extractor.extract(new)
        if (new.persons, new.groups, new.feature_keys()) != (old.persons, old.groups, old.feature_keys()):
            changed.append((old.incident_id, old.persons - new.persons, old.groups - new.groups))
            if apply:
                store.add_incident(new, db_path=db_path)
    return changed


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--apply", action="store_true", help="save the changes")
    args = ap.parse_args()
    import app as sirens     # uses the app's extractor, with its known places
    changed = reextract(sirens._EXTRACTOR, apply=args.apply)
    for iid, people, groups in changed:
        gone = ", ".join(sorted(people | groups)) or "features only"
        print(f"{iid}: no longer a person/group: {gone}")
    print(f"{len(changed)} report(s) {'updated' if args.apply else 'would change; run with --apply to save'}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
