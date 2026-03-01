# Repository Agent Guide

This repository contains the World of Warcraft addon `MuteValeera`.

## Repo Rules

- Keep changes focused on the addon source, release automation, and documentation needed to ship the addon.
- Treat `MuteValeera.lua` and `MuteValeera.toc` as the source of truth for runtime behavior and addon metadata.
- Keep the addon locale-independent. Prefer sound IDs, events, and WoW APIs over localized text matching.
- Preserve existing slash commands and saved-variable behavior unless a documented breaking change is intentional.
- For user-visible behavior changes, update `CHANGELOG.md` in the same change.
- For versioned releases, keep the version in `MuteValeera.toc`, the tag, and the changelog aligned.
- Do not commit packaged zip files, generated release output, WoW SavedVariables backups, or local editor/account state.
- If you add files that should not ship in the packaged addon, update `.pkgmeta` ignore rules as part of the same change.
- Keep the built-in mute list limited to Valeera Sanguinar `vo_120` delve-companion voice assets from the Wago Tools `Valeera` file search on pages `9` through `15` that were updated after build `12.0.0.63534`.
- Use the Wago Tools `Valeera` file search on pages `9` through `15` as the first-pass candidate pool unless the repository owner explicitly expands it.
- If a Valeera asset is ambiguous or not clearly companion VO, exclude it instead of guessing.

## Release Rules

- Releases are triggered by pushing a git tag that matches `v*`.
- GitHub Actions workflow `.github/workflows/release.yml` packages through `BigWigsMods/packager@v2`, creates GitHub releases, and publishes to CurseForge project `1475450`.
- The GitHub Actions repository secret name for CurseForge publishing is `CF_API_KEY`.
- Before tagging a release, confirm:
  - `MuteValeera.toc` has the intended version.
  - `CHANGELOG.md` includes the release notes.
  - `.pkgmeta` still excludes non-distribution files.
  - Local packaging or a smoke test has been run when the change affects packaging, loading, or command behavior.
- Do not commit manual edits to generated files under `release/`.

## PR Checklist

- The addon loads without Lua errors.
- Slash commands and settings still work, or the change documents any intentional behavior difference.
- `CHANGELOG.md` is updated for user-facing changes.
- `MuteValeera.toc` version is updated when preparing a release.
- New files are reviewed for whether they belong in the packaged addon and whether `.pkgmeta` or `.gitignore` must change.
- No secrets, tokens, personal paths, or local editor/account files are included in the diff.
- If release automation was touched, verify `.github/workflows/release.yml`, `.pkgmeta`, and `PUBLISHING.md` still agree on the release process.

## Multi-Account VS Code Notes

- Use VS Code profiles or account switching outside the repository for GitHub identity, Copilot identity, and Settings Sync.
- Keep workspace auth state, account preferences, and machine-specific settings out of git.
- Do not commit `.vscode` files unless the repository owner explicitly wants shared workspace settings and the file is free of personal paths, tokens, and account identifiers.
- Prefer local-only workspace files such as `.code-workspace` or ignored `.vscode` settings for machine-specific Lua paths and extension configuration.
- Before committing from a secondary GitHub account, confirm `git config user.name`, `git config user.email`, and the active GitHub authentication context match the intended account.

## Strict Secret-Handling Rules

- Never commit API keys, tokens, cookies, session exports, private URLs with embedded credentials, or screenshots/logs that reveal them.
- Never place credentials directly in source files, `PUBLISHING.md`, PR descriptions, issues, commit messages, or local files intended for commit.
- The CurseForge token belongs only in the GitHub Actions secret named `CF_API_KEY`.
- Treat `.env`, `.env.*`, key files, exported auth JSON, and local release notes containing secrets as non-committable.
- If a secret is exposed or even suspected to be exposed:
  - stop using it;
  - rotate or revoke it immediately;
  - remove it from the working tree and any queued commits;
  - document the cleanup in a security-conscious way without repeating the secret value.
