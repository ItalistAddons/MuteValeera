# Publishing

This repository publishes from GitHub to CurseForge through tag-driven GitHub Actions automation.

## Repository

- GitHub: `https://github.com/ItalistAddons/MuteRepetitiveBrann`
- Issues: `https://github.com/ItalistAddons/MuteRepetitiveBrann/issues`
- CurseForge: `https://www.curseforge.com/wow/addons/mute-repetitive-brann`

## Release Model

- Releases are tag-driven and automated.
- Pushing a tag that matches `v*` triggers `.github/workflows/release.yml`.
- The release workflow uses `BigWigsMods/packager@v2`.
- CurseForge publishing uses the GitHub Actions repository secret `CF_API_KEY`.
- Never commit tokens. Do not place CurseForge credentials in tracked files, PR text, issues, or local config intended for commit.

## Maintainer Setup

1. Generate a CurseForge API token at `https://www.curseforge.com/account/api-tokens`.
2. In the GitHub repository, open `Settings -> Secrets and variables -> Actions`.
3. Add a repository secret named `CF_API_KEY`.
4. Do not rename the secret unless the workflows and documentation are updated in the same change.

## Release Checklist

1. Update `MuteRepetitiveBrann.toc` so `## Version:` matches the intended release.
2. Update `CHANGELOG.md`.
3. Confirm `.pkgmeta` still excludes non-runtime files.
4. Confirm CI passed on the commit you are tagging.
5. Create and push the tag:

```powershell
git tag v1.4.2
git push origin main --tags
```

## What the Release Workflow Does

- validates the root `MuteRepetitiveBrann.toc`
- validates the tag version against `## Version:`
- confirms `.pkgmeta` is present
- confirms `## X-Curse-Project-ID:` is present in the TOC
- confirms `CF_API_KEY` is available
- packages the addon with the BigWigs packager
- creates or updates the GitHub release
- uploads the packaged addon to CurseForge
- uploads the generated `.release/*.zip` as a diagnostic GitHub Actions artifact

## CI vs Release

- `.github/workflows/ci.yml` is build-only.
- CI packages with the same packager in dry-run mode and uploads the built zip as a workflow artifact.
- CI does not publish to CurseForge.
- Tagged releases are the only publishing path.

## Local Dry-Run Packaging

Use the repository wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .\package.ps1
```

This wrapper uses the official BigWigs packager in dry-run mode and writes output under `.release/`.

## Windows Troubleshooting

- Install WSL or Git Bash. `package.ps1` requires one of them because the official packager is a shell script.
- Run the command from the repository root.
- This repository path contains spaces and parentheses, so keep the path quoted if you run commands manually.
- If the wrapper reports missing prerequisites, install WSL or Git Bash and try again.
- If packaging fails, compare the local `.release/` contents with the zip artifact from the latest CI run.
- If a local `.env` file is used for packager testing, keep it untracked and never commit it.
- Never place the CurseForge token in source files, docs, or tracked config. Automation uses only the GitHub secret `CF_API_KEY`.

## Direct Packager Invocation

If you need to run the packager manually from a Unix-like shell:

```bash
curl -fsSL https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash -s -- -d
```

Run that command from the repository root so the packager finds `.pkgmeta` and the root TOC.
