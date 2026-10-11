# Sirens — Weekly KPI Scoreboard

Team: Elie Boutros, Bassam Eter (one team, no individual feature ownership)
Capacity: ~10 h/week total
Start: week of 2026-10-12 · Deadline: end of month (exact date TBC)
Deliverable: live demo + written report + code

**Rules:** each session states this week's KPI, works only on it, and ends by
ticking what is done. Cut-line: defer the lowest item rather than extend into
week 4. Only tick an item when it has been verified (pasted output or a
working check), not just "edited".

Status: [x] done (verified) · [~] in progress · [ ] not started

## W1 — Foundation
- [~] Feature branch pushed (`bassam/w1-foundation` on fork; PR to main repo pending)
- [x] `.gitignore` excludes `data/sirens.db*`, `.venv`, `__pycache__`; tracked DB removed
- [ ] Fresh clone runs from README in <= 10 min (timed, on a second machine)
- [ ] Demo-mode button loads sample data
- [~] htmx + Chart.js load from `static/vendor/` with network off
- [~] DB tables for link decisions and notes exist (new module, not `store.py`)

## W2 — Analyst workbench
- [ ] Confirm / Reject / Unsure on every link, no page reload
- [ ] Decisions + notes persist across restart
- [ ] Scripted 10-click test: zero server errors

## W3 — Dashboard + auto-flagging
- [ ] Timeline chart + 2 more charts + working filters
- [ ] Saving a report shows its likely network with band + reasons (first to defer)

## W4 — Freeze / polish / deliver
- [ ] Tooltips on all form fields
- [ ] Regression test fails if F1 < 0.73
- [ ] README with screenshots
- [ ] Written report, first draft
- [ ] Deck updated
- [ ] Full demo rehearsal with the model pre-loaded
- Stretch: CSV/JSON import · live threshold slider · completeness badge

## Measured accuracy (only numbers we actually measured)
| Date | Data | Threshold | P | R | F1 |
|---|---|---|---|---|---|
| (before W1) | 100 synthetic, seed 7 | 0.25 | 0.628 | 0.888 | 0.736 |

Target: P 0.90 / R 0.80 / F1 0.85.

## Open items to verify on Elie's laptop
- `app.run` uses `debug=False`
- UI width / watermark / checkbox-spacing CSS edits landed
- Brief page "Incidents on record here" list (query.py + brief_bp.py)
- Whether `tests/` exists
- Back up local `data/sirens.db` BEFORE pulling the commit that untracks it

## Session log
- 2026-10-12 (Bassam, browser): forked repo, created branch, fixed
  `.gitignore`, untracked `sirens.db`, added this scoreboard.
    Also: vendored htmx 2.0.11 + Chart.js 4.5.1; added linker/decisions.py
  (written in browser, NOT yet run: verify with `python -m linker.decisions`).
