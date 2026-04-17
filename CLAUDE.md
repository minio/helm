# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This repo is the **MinIO AIStor Helm chart repository** served at https://helm.min.io/ (CNAME in `CNAME`, GitHub Pages via `_config.yml`). It is **not** a source repository for the charts themselves — upstream chart source lives in other MinIO repos (e.g., https://github.com/minio/aistor). This repo only hosts packaged `.tgz` chart artifacts and the `index.yaml` that `helm repo add` consumes.

## Layout

- `helm-releases/` — packaged chart tarballs (`<chart>-<version>.tgz`). Every published version is retained; nothing is deleted.
- `index.yaml` — the Helm repo index consumed by clients. URLs in it point to `https://helm.min.io/helm-releases/<chart>-<version>.tgz`.
- `helm-index.sh` — the **only** supported way to regenerate `index.yaml`.
- `index.yaml~` — backup written by `helm-index.sh` (gitignored).
- `README.md` — end-user install instructions for each chart (aistor-objectstore-operator, aistor-keymanager-operator, aistor-volumemanager / DirectPV, etc.).

Current chart families in `helm-releases/`: `aistor-keymanager`, `aistor-keymanager-operator`, `aistor-objectstore`, `aistor-objectstore-operator`, `aistor-operator`, `aistor-volumemanager`, `directpv`, `hperf`, `minkms`, `minkms-operator`, `warp`.

## Publishing a new chart version

1. Drop the new `<chart>-<version>.tgz` into `helm-releases/`.
2. Run `./helm-index.sh` to regenerate `index.yaml`.
3. Commit both the new tarball and the updated `index.yaml`.

### Why `helm-index.sh` and not `helm repo index` directly

A plain `helm repo index . --url https://helm.min.io --merge index.yaml` rewrites the `created` timestamps of entries whose tarball mtime has changed (e.g., after a fresh `git clone`). `helm-index.sh` runs that command, then uses `yq` to match each new entry against the old index **by digest** and restore the original `created` timestamp. This keeps timestamps stable across re-indexes — important because clients and mirrors key off them. See commit `87880f4` for the rationale.

Requirements: `helm` and `yq` (the Go/mikefarah variant, which supports `eval-all` and multi-document input) on PATH.

### Do not

- Do not hand-edit `index.yaml` — always regenerate with `helm-index.sh`.
- Do not delete old `.tgz` files or their index entries; existing installs pin to specific versions.
- Do not change the `--url` passed to `helm repo index` (it must stay `https://helm.min.io` to match the CNAME).

## Hosting

GitHub Pages serves the repo root over the `helm.min.io` CNAME. Pushing to `main` publishes; there is no build step beyond Jekyll's default (`_config.yml` sets `theme: jekyll-theme-minimal` only because Pages requires a theme — nothing in this repo renders as a site).
