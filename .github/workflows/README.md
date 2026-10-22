# GitHub Actions build

The workflow follows the working `ruik3z/orangefox-pipa` Hosted Runner setup,
but targets the newer OrangeFox `fox_16.0` manifest and this repository's
`device/xiaomi/pipa` tree.

Build steps:

- run `slimhub_actions` before allocating build space;
- install the OrangeFox Android build environment;
- enable the large workspace volume and zram;
- run `orangefox_sync.sh --branch 16.0`;
- clone this repository at the triggering commit into `device/xiaomi/pipa`;
- run `lunch twrp_pipa-bp2a-eng`, `make clean` and `mka adbd bootimage`.

## Triggers

- Run **OrangeFox - Build pipa** manually to build and retain a workflow
  artifact.
- Set `publish_release` and `release_tag` in a manual run to publish a release.
- Push a tag such as `orangefox-pipa-20261022` to build and publish
  automatically.

Every successful build uploads:

- the OrangeFox recovery images and ZIPs produced by the build;
- the boot image intended for direct flashing;
- the optional `fastboot boot` image;
- `SHA256SUMS.txt`, `BUILD_INFO.txt` and generated release notes.

## Failure logs

A failing build starts a separate `diagnose` job. It uses the workflow's
built-in `GITHUB_TOKEN` with `actions: read` to download the complete Actions
log, even when the main Runner loses communication during the final build
stage.

## Required permissions

No repository secrets are required. The release path uses the workflow's
built-in `GITHUB_TOKEN` with `contents: write`.
