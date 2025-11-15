# ForgeLoop Rebrand Plan (Demo-Focused)

Goal: For an imminent demo, minimize risk and time while ensuring screenshots and common user flows show ForgeLoop branding. Prioritize low-risk, necessary changes; defer high-risk or unnecessary work.

## Low Risk & Necessary Changes
- Update visible names in prompt/command templates:
  - Rename `/speckit.*` command names in template filenames and front‑matter to `/forgeloop.*` where filenames are user-visible in screenshots.
  - Ensure descriptions and headers say “ForgeLoop”.
- Update top-level docs branding where screenshots are likely taken:
  - README title/logo alt text and first paragraph to “ForgeLoop”.
  - docs/quickstart.md headings and first usage examples (keep legacy notes minimal).
- Update user-facing strings in CLI only where shown in screenshots or obvious outputs:
  - Banners, taglines, success messages: “Specify/Spec Kit” → “ForgeLoop”.
  - Keep internal module/package name `specify_cli` to avoid risk.
- Add CLI alias without breaking existing usage:
  - Provide `forgeloop` (or `forge`) as an additional console script mapping to the same entrypoint. Keep `specify` working.
- Non-code assets:
  - Swap logo alt text to ForgeLoop; keep file names as-is if changing files is risky.
- Versioning housekeeping (required by AGENTS.md):
  - If `src/specify_cli/__init__.py` is touched, bump version in `pyproject.toml` and add a brief CHANGELOG entry.

## High Risk & Unnecessary Changes (Defer)
- Renaming Python package/module (`specify_cli` → `forgeloop_cli`).
- Changing repository names/URLs or automation that depends on `spec-kit` identifiers.
- Overhauling release artifacts and workflow scripts (`spec-kit-template-*` → `forge-loop-*`).
- Removing legacy `/speckit.*` commands; deep refactors of templates/scripts.
- Widespread internal identifier renames not visible in demo outputs.

## Concrete Next Steps (Demo Sprint)
1) Template filenames and fronts:
   - `templates/commands/*` → ensure command names present as `/forgeloop.*` in visible text; keep legacy references if needed but prefer ForgeLoop.
2) Update limited CLI messaging:
   - In `src/specify_cli/__init__.py`, change `TAGLINE`, banners, and “Specify” labels to “ForgeLoop”. Avoid altering behavior.
3) Docs touch‑up for screenshot areas:
   - `README.md` top block; `docs/quickstart.md` first examples.
4) Add CLI alias (if packaging used in demo):
   - Expose `forgeloop` entrypoint alongside `specify` (requires `pyproject.toml` console_scripts change).
5) Comply with versioning rules:
   - Bump version; add `CHANGELOG.md` entry.

Notes:
- Keep all legacy names operational. This is a cosmetic/UX pass for demo readiness.
