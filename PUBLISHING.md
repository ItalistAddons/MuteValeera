# Publishing

This repository publishes packaged GitHub releases through tag-driven GitHub Actions automation.

## Repository

- GitHub: `https://github.com/ItalistAddons/MuteValeera`
- Issues: `https://github.com/ItalistAddons/MuteValeera/issues`

## Release Model

- Releases are tag-driven and automated
- Pushing a tag that matches `v*` triggers `.github/workflows/release.yml`
- The release workflow uses `BigWigsMods/packager@v2`
- The current release path is GitHub-first; CurseForge publishing is intentionally disabled until a real project exists
- Never commit tokens or place credentials in tracked files, PR text, issues, or local config intended for commit

## Maintainer Setup

1. Ensure GitHub Actions is enabled for the repository
2. Keep the tag-only workflow name `Package and Release`
3. Keep the always-on CI check name `validate-and-package` if you use the documented branch protection settings
4. If CurseForge publishing is enabled later, use the GitHub Actions secret name `CF_API_KEY` consistently across workflows and docs

## Release Checklist

1. Update `MuteValeera.toc` so `## Version:` matches the intended release
2. Update `CHANGELOG.md`
3. Confirm `.pkgmeta` still excludes non-runtime files
4. Confirm CI passed on the commit you are tagging
5. Create and push the tag:

```powershell
git tag v1.0.0
git push origin main --tags
```

## What the Release Workflow Does

- validates the root `MuteValeera.toc`
- validates the tag version against `## Version:`
- confirms `.pkgmeta` is present
- packages the addon with the BigWigs packager
- creates or updates the GitHub release
- uploads the generated `.release/*.zip` as a diagnostic GitHub Actions artifact

## CI vs Release

- `.github/workflows/ci.yml` is build-only
- CI packages with the same packager in dry-run mode and uploads the built zip as a workflow artifact
- CI does not publish anywhere
- Tagged releases are the only publishing path

## Local Dry-Run Packaging

Use the repository wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .\package.ps1
```

This wrapper uses the official BigWigs packager in dry-run mode and writes output under `.release/`.

## Windows Troubleshooting

- Install WSL or Git Bash; `package.ps1` requires one of them because the official packager is a shell script
- Run the command from the repository root
- This repository path contains spaces and parentheses, so keep the path quoted if you run commands manually
- If the wrapper reports missing prerequisites, install WSL or Git Bash and try again
- If packaging fails, compare the local `.release/` contents with the zip artifact from the latest CI run
- If a local `.env` file is used for packager testing, keep it untracked and never commit it
- If CurseForge support is added later, keep any token in GitHub Actions secrets only and never in tracked files

## Direct Packager Invocation

If you need to run the packager manually from a Unix-like shell:

```bash
curl -fsSL https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash -s -- -d
```

Run that command from the repository root so the packager finds `.pkgmeta` and the root TOC.
