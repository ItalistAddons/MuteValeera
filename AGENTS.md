# Repository Agent Guide

This repository contains the World of Warcraft addon `MuteRepetitiveBrann`.

## Repo Rules

- Keep changes focused on the addon source, release automation, and documentation needed to ship the addon.
- Treat `MuteRepetitiveBrann.lua` and `MuteRepetitiveBrann.toc` as the source of truth for runtime behavior and addon metadata.
- Keep the addon locale-independent. Prefer sound IDs, events, and WoW APIs over localized text matching.
- Preserve existing slash commands and saved-variable behavior unless a documented breaking change is intentional.
- For user-visible behavior changes, update `CHANGELOG.md` in the same change.
- For versioned releases, keep the version in `MuteRepetitiveBrann.toc`, the tag, and the changelog aligned.
- Do not commit packaged zip files, generated release output, WoW SavedVariables backups, or local editor/account state.
- If you add files that should not ship to CurseForge, update `.pkgmeta` ignore rules as part of the same change.

## Release Rules

- Releases are triggered by pushing a git tag that matches `v*`.
- GitHub Actions workflow `.github/workflows/release.yml` packages and publishes through `BigWigsMods/packager@v2`.
- CurseForge publishing must use the GitHub Actions repository secret named `CF_API_KEY`.
- Do not rename `CF_API_KEY` in workflow files or documentation unless the repository owner explicitly requests a coordinated change everywhere.
- Before tagging a release, confirm:
  - `MuteRepetitiveBrann.toc` has the intended version.
  - `CHANGELOG.md` includes the release notes.
  - `.pkgmeta` still excludes non-distribution files.
  - Local packaging or a smoke test has been run when the change affects packaging, loading, or command behavior.
- Do not commit manual edits to generated files under `release/`.

## PR Checklist

- The addon loads without Lua errors.
- Slash commands and settings still work, or the change documents any intentional behavior difference.
- `CHANGELOG.md` is updated for user-facing changes.
- `MuteRepetitiveBrann.toc` version is updated when preparing a release.
- New files are reviewed for whether they belong in the CurseForge package and whether `.pkgmeta` or `.gitignore` must change.
- No secrets, tokens, personal paths, or local editor/account files are included in the diff.
- If release automation was touched, verify `.github/workflows/release.yml`, `.pkgmeta`, and `PUBLISHING.md` still agree on the release process and the `CF_API_KEY` secret name.

## Multi-Account VS Code Notes

- Use VS Code profiles or account switching outside the repository for GitHub identity, Copilot identity, and Settings Sync.
- Keep workspace auth state, account preferences, and machine-specific settings out of git.
- Do not commit `.vscode` files unless the repository owner explicitly wants shared workspace settings and the file is free of personal paths, tokens, and account identifiers.
- Prefer local-only workspace files such as `.code-workspace` or ignored `.vscode` settings for machine-specific Lua paths and extension configuration.
- Before committing from a secondary GitHub account, confirm `git config user.name`, `git config user.email`, and the active GitHub authentication context match the intended account.

## Strict Secret-Handling Rules

- Never commit API keys, tokens, cookies, session exports, private URLs with embedded credentials, or screenshots/logs that reveal them.
- Never place the CurseForge API token directly in source files, `PUBLISHING.md`, PR descriptions, issues, commit messages, or local files intended for commit.
- The CurseForge token belongs only in the GitHub Actions secret named `CF_API_KEY`.
- Treat `.env`, `.env.*`, key files, exported auth JSON, and local release notes containing secrets as non-committable.
- If a secret is exposed or even suspected to be exposed:
  - stop using it;
  - rotate or revoke it immediately;
  - remove it from the working tree and any queued commits;
  - document the cleanup in a security-conscious way without repeating the secret value.
