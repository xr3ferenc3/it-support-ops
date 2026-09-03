# Releasing ITSupportOps to the PowerShell Gallery

This document describes how a new version gets published. Read this before
your first release - the order of operations matters, and doing it out of
order produces a confusing failure rather than a clean one.

## One-time setup (do this once, before your first release)

1. Create a free account at [powershellgallery.com](https://www.powershellgallery.com)
   if you don't have one (sign in with a Microsoft or GitHub account)
2. Go to your account menu → **API Keys** → **Create**
   - Scope it to **push new packages and package versions**
   - Optionally restrict it to just the `ITSupportOps` package name (safer -
     if this key is ever compromised, it can't be used to publish anything else)
   - Copy the key immediately - PSGallery only shows it once
3. In the GitHub repository: **Settings → Secrets and variables → Actions →
   New repository secret**
   - Name: `PSGALLERY_API_KEY`
   - Value: the key you just copied
4. Done. This only needs to happen once - the release workflow reuses this
   secret for every future release.

## Every release: the order that matters

**Bump the version before you tag, not after.** The release workflow
(`.github/workflows/release.yml`) hard-fails if the git tag doesn't exactly
match `ModuleVersion` in `module/ITSupportOps/ITSupportOps.psd1`. This is
deliberate - PSGallery permanently rejects re-publishing an existing version
number, so catching a mismatch here with a clear message is much better than
discovering it in a failed publish step.

1. **Decide the new version number** using semantic versioning:
   - `1.0.0` → `1.0.1`: bug fix, no behavior change a user would notice
   - `1.0.0` → `1.1.0`: new functionality, backward compatible (e.g. adding
     a new cmdlet or an optional parameter)
   - `1.0.0` → `2.0.0`: breaking change (e.g. renaming a cmdlet, changing
     a parameter's meaning, removing something)

2. **Update `module/ITSupportOps/ITSupportOps.psd1`:**
   ```powershell
   ModuleVersion     = '1.0.1'   # was '1.0.0'
   ```
   Also update `ReleaseNotes` in the same file's `PSData` block with a short
   summary of what changed - this is what shows up on the PSGallery listing
   page.

3. **Update `CHANGELOG.md`:** move the relevant `[Unreleased]` entries under
   a new `## [1.0.1] - 2026-MM-DD` heading, following the format already
   used for `[0.1.0]`.

4. **Commit and push these changes to `main` first, as their own commit(s),
   and confirm CI is green** before tagging. Tagging a commit where CI is
   red just automates publishing a broken release faster.

5. **Tag and push the tag:**
   ```bash
   git tag v1.0.1
   git push --tags
   ```
   The `v` prefix on the tag is required - the workflow strips it before
   comparing against `ModuleVersion`.

6. **Watch the Actions tab.** The release workflow will:
   - Verify the tag matches the manifest version (fails fast if not)
   - Re-verify `module/ITSupportOps/Scripts` is in sync with `scripts/windows`
     (defense in depth - this should already be guaranteed by the main CI
     workflow before merge, but a release is worth double-checking)
   - Validate the manifest with `Test-ModuleManifest`
   - Import the module fresh and confirm it exports the expected commands
   - Publish to PSGallery
   - Create a GitHub Release with generated release notes

7. **Verify the release actually works**, from a machine that doesn't
   already have the module cached:
   ```powershell
   Install-Module ITSupportOps -Force
   Get-Command -Module ITSupportOps
   ```

## If something goes wrong

- **Tag/manifest version mismatch:** delete the tag (`git tag -d v1.0.1 &&
  git push --delete origin v1.0.1`), fix the manifest, commit, and re-tag.
- **PSGallery rejects the publish for an unrelated reason:** the tag and
  GitHub Release will already exist even though the PSGallery publish
  failed. Delete both, fix the underlying issue, and start again from
  step 4 - don't reuse a tag that already exists.
- **You need to run the release workflow manually** (e.g. to retry after
  fixing something, without pushing a new tag): use the "Run workflow"
  button on the Actions tab (`workflow_dispatch`), and type `publish`
  exactly when prompted. This still runs the manifest validation and
  publish step, but skips the tag/manifest version comparison since there's
  no tag involved in a manual run - double-check the version yourself
  before doing this.

## Manual publish (only if the workflow is broken and you need to ship urgently)

```powershell
$apiKey = Read-Host -AsSecureString "PSGallery API key"
$plainKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey))
Publish-Module -Path .\module\ITSupportOps -NuGetApiKey $plainKey
```

Treat this as a last resort. The workflow's checks exist because manual
publishing is exactly how version mismatches and out-of-sync scripts slip
through.
