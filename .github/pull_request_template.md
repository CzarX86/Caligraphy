## Summary

Explain the problem and the approach. Include context and goals.

## Changes

- What changed at a high level
- Modules touched (e.g., UI, ScoringEngine, HandwritingKit)

## Screenshots / Videos (UI)

Add before/after images or a short screen recording when UI changes.

## How To Test

1. `xcodegen generate` (ensure project is up to date)
2. Open the `.xcodeproj`, select an iOS Simulator (iPad preferred)
3. Build & Run; verify feature behavior
4. Optional: `swiftlint` locally and `xcodebuild … test`

## Risks & Rollout

- Potential impact areas
- Manual QA required?

## Checklist

- [ ] Builds and runs on simulator
- [ ] Lint passes (`swiftlint` clean)
- [ ] Tests added/updated (if applicable) and pass
- [ ] Updated docs (README/AGENTS.md) as needed
- [ ] No large assets committed; templates under `Resources/Templates/`
- [ ] Linked issues with GitHub keywords (Fixes/Closes #123)

