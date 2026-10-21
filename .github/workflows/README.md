# GitHub Actions build

The workflow builds on GitHub-hosted `ubuntu-24.04` runners. It follows the
working Hosted Runner setup used by the Pipa OrangeFox workflow:

- install Android build dependencies;
- use `easimon/maximize-build-space` to move the work area onto the large
  temporary volume;
- apply OrangeFox's pinned recovery-only `remove-minimal.xml` local manifest,
  which removes several hundred AOSP projects that are not used by recovery;
- enable zram to reduce Android build memory pressure.

## Triggers

- Run **Build TWRP pipa** manually to build and retain a workflow artifact.
- Set `publish_release` and `release_tag` in a manual run to publish a release.
- Push a tag such as `twrp-16.0-pipa-20261018` to build and publish
  automatically.

Every successful build also uploads a workflow artifact containing:

- the image intended for direct flashing;
- the optional `fastboot boot` image;
- `SHA256SUMS.txt`;
- `BUILD_INFO.txt` and generated release notes.

## Cache

The workflow uses `hendrikmuhs/ccache-action`, enables the AOSP ccache
variables, and disables the Soong sandbox so the ccache compiler wrapper can be
used. The cache is limited to 2 GiB.

## Required permissions

No repository secrets are required. The tag/manual release path uses the
workflow's built-in `GITHUB_TOKEN` with `contents: write`.
