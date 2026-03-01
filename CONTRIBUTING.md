# Contributing

This repository contains the World of Warcraft addon `MuteValeera`.

## Development Basics

- Runtime addon files live at repository root
- The main runtime files are `MuteValeera.toc` and `MuteValeera.lua`
- Update `CHANGELOG.md` for user-visible changes
- Review `.pkgmeta` when adding, removing, or renaming files so packaging stays correct
- Validate changes in game when possible, especially slash commands, settings, and muting behavior

## Valeera Data Scope

- The built-in mute list must only contain Valeera Sanguinar `vo_120` delve-companion voice assets from the audited Wago Tools candidate pool on pages `9` through `15`
- The initial candidate pool for this repository is the Wago Tools `Valeera` file search on pages `9` through `15`
- Keep only files that were updated after build `12.0.0.63534`
- If a file is ambiguous or not clearly Valeera companion VO, exclude it instead of guessing
- Do not broaden the addon into "mute all Valeera" without an explicit design decision

## Release Workflow

- Releases are tag-driven and automated
- Pushing a tag that matches `v*` triggers `.github/workflows/release.yml`
- GitHub Actions packages the addon, creates a GitHub release, and publishes to CurseForge through the BigWigs packager
- CurseForge publishing targets project ID `1475450` and uses the repository secret `CF_API_KEY`
- Never commit tokens or place credentials in source files, docs, issues, pull requests, or tracked local config
- CI is build-only and does not publish; publishing happens only on tagged releases

## Pull Request Expectations

- Keep pull requests focused
- Explain behavioral changes clearly
- Update `CHANGELOG.md` for user-facing changes
- Align the `.toc` version, changelog, and release tag when preparing a release
- Confirm that no secrets or machine-specific files are included
- Keep packaging-related files consistent with the shipped addon layout

## Maintainer Setup

Configure branch protection for `main` in GitHub with these exact settings:

- Require a pull request before merging: enabled
- Required approvals: `1`
- Dismiss stale pull request approvals when new commits are pushed: enabled
- Require review from code owners: disabled
- Require approval of the most recent reviewable push: enabled
- Require status checks to pass before merging: enabled
- Require branches to be up to date before merging: enabled
- Required status checks:
  - `validate-and-package`
- Require conversation resolution before merging: enabled
- Require signed commits: disabled
- Require linear history: enabled
- Require merge queue: disabled
- Allow merge commits: disabled
- Allow squash merging: enabled
- Allow rebase merging: enabled
- Allow auto-merge: enabled
- Restrict pushes that create matching branches: disabled
- Allow force pushes: disabled
- Allow deletions: disabled
- Do not require the tag-only workflow `Package and Release` as a status check, because it runs only for pushed tags matching `v*`
- Keep `validate-and-package` as the required status check unless a new always-on PR check is intentionally added

## Security and Secrets

- Never commit API keys, tokens, cookies, exported auth state, or private credential-bearing URLs
- If you use a local `.env` file for packager testing, keep it untracked and never copy its contents into issues, PRs, or committed docs
- The approved GitHub Actions secret name for CurseForge publishing is `CF_API_KEY`
- If a secret is exposed or suspected to be exposed, revoke or rotate it immediately and remove it from pending commits without repeating the secret value

## Issues

- Use the GitHub issue templates for bug reports and feature requests
- Do not paste secrets or account/session data into issues
- Issue forms live under `.github/ISSUE_TEMPLATE/`

## Windows Troubleshooting

- Local dry-run packaging uses the official packager path via `package.ps1`, not manual file copying
- Run packaging commands from the repository root
- This repository path contains spaces and parentheses, so preserve quoting if you invoke commands manually
- On Windows, install WSL or Git Bash before running `package.ps1`
- If local packaging fails, compare the local `.release/` output and the GitHub Actions artifacts described in `PUBLISHING.md`
