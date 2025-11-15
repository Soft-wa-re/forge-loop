# ForgeLoop Rebrand Plan (Demo-Focused)

Goal: For the imminent demo, minimize risk and time while ensuring screenshots and common user flows show ForgeLoop branding. Track status and quality as we go.

## 1) Necessary / Low-Risk Changes
- Templates and prompts
  - Replace visible `/speckit.*` with `/forgeloop.*` in command templates and notes.
  - Keep legacy references where needed for continuity.
- Docs top-level branding
  - README title/logo alt, first paragraphs to “ForgeLoop”.
  - docs/quickstart.md headings and first examples.
- CLI visible text only
  - Banner/tagline, success messages switch to “ForgeLoop”.
  - Keep package/module `specify_cli`, behavior, and entrypoint the same.
- Non-code assets
  - Update alt text to ForgeLoop; avoid renaming files right now.
- Versioning rule (AGENTS.md)
  - If `src/specify_cli/__init__.py` is modified, bump version and add CHANGELOG.

Status: Completed in repo for templates, README top, quickstart, and key CLI messages. Version bump pending (alias decision impacts this).

Quality check
- Grep shows updated strings in affected files.
- CLI runs with same entrypoint; only messages changed.

## 2) High/Medium Value for Screenshots (Optional before demo)
- Add CLI alias `forgeloop` (or `forge`) in pyproject while retaining `specify`.
- Update GIF captions and headings where visible in screenshots.
- Prefer `/forgeloop.*` in tables/lists where users scan quickly; mention legacy once.

Risk: Low to medium (requires version bump and CHANGELOG for alias). Impact: Improves screenshot/story consistency.

Status: Pending decision on alias name.

Quality check
- After alias: verify `uv tool install specify-cli --from <repo>` still exposes `specify` and new alias.
- Smoke test `init` path prints ForgeLoop messaging.

## 3) Deep Code Changes (Defer post-demo)
- Rename Python package/module to `forgeloop_cli` with a shim for `specify_cli`.
- Change release artifacts and workflow identifiers from `spec-kit*` to `forge-loop*`.
- Update AGENTS.md comprehensive branding and script examples.
- Migrate repo names/URLs and all cross-links.

Status: Not started (intentionally deferred).

Quality check
- Plan phased migration with deprecation notices and redirects.

## Concrete Next Steps (Sprint)
1) Decide CLI alias: `forgeloop` or `forge`.
2) If approved, add alias to pyproject, bump version, add CHANGELOG entry.
3) Spot-check remaining docs sections for screenshot-critical branding.

Notes
- Legacy names remain operational; this is a cosmetic/UX pass for demo readiness.
