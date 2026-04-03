# Releasing NeatEditor

This repository uses a tag-driven GitHub Actions workflow to build and publish release assets.

## What Happens On Release

When you push a tag like `v1.0.0`, GitHub Actions will:

- select Xcode 16.2
- generate the Xcode project with XcodeGen
- build a Release configuration macOS app
- package `NeatEditor.app` as a universal zip
- generate `SHA256SUMS.txt`
- create or update the matching GitHub Release

## Release Asset Names

The generated asset name follows this pattern:

```text
NeatEditor-v1.0.0-macOS-universal.zip
```

## Publish A Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

After the workflow finishes, open the repository's Releases page to verify:

- the release exists for the tag
- the zip asset was uploaded
- the checksum file was uploaded

## Important Notes

- The current workflow produces an unsigned build artifact.
- Users may still need to bypass Gatekeeper manually when opening the app.
- If you want frictionless public downloads, the next step is to add Apple code signing and notarization secrets to the workflow.

## Versioning

- The tag name without the leading `v` becomes `MARKETING_VERSION`.
- `CURRENT_PROJECT_VERSION` is set from the GitHub Actions run number.

## Re-running A Failed Release

If the tag already exists, fix the workflow or repository state first, then re-run the workflow from GitHub Actions.
