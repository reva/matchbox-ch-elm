# AGENTS.md

Instructions for coding agents working on this repository.

## What this repo is

A thin Docker image on top of [matchbox](https://github.com/ahdis/matchbox) that preloads the
CH ELM implementation guide (`ch.fhir.ig.ch-elm`) for validation. There is no application code:
a release is a new combination of matchbox version and ch-elm IG version.

| File | Purpose |
| --- | --- |
| `Dockerfile` | `FROM europe-west6-docker.pkg.dev/ahdis-ch/ahdis/matchbox:vX.Y.Z`, the matchbox base image |
| `src/ch.fhir.ig.ch-elm.tgz` | the ch-elm IG package that gets installed into the image |
| `src/application.yaml` | matchbox config; the ch-elm version appears in **two** places (`hapi.fhir.implementationguides.chelm.version` and `matchbox.fhir.context.igsPreloaded`) |
| `changelog.md` | release history, newest entry first |
| `.github/workflows/prepare-release.yml` | `Prepare a release`, weekdays or by hand with specific versions: runs `.github/scripts/prepare-release.sh`, builds the image and opens the release PR from `feat/next-release` |
| `.github/scripts/prepare-release.sh` | updates `Dockerfile`, the IG package, `src/application.yaml`, `changelog.md` and `README.md` to a new matchbox and/or ch-elm version and picks the release version |
| `.github/workflows/release.yml` | `Create a release`, on a push to `main` that adds a `changelog.md` entry (or by hand with a version): creates the tag and the GitHub release with the notes from `changelog.md`, then starts `build.yml` on the tag (passing the `gar` and `zulip` options) |
| `.github/workflows/build.yml` | on every pushed tag (or started by `release.yml`), builds the image (amd64 and arm64) and pushes it to `ghcr.io/ahdis/matchbox-ch-elm` as `<tag>` and the tags of `.github/scripts/version.sh --tags`; also to Google Artifact Registry and posts to Zulip (`#matchbox`), unless `gar` / `zulip` are turned off |
| `.github/scripts/version.sh` | prints the version of the image in the working tree (`<ch-elm>-<matchbox>`, for a ci-build `<ch-elm>-cibuild.<package date>-<matchbox>`), with `--tags` also the tag of its latest build |

## Release process

Releases are made by merging the PR of `prepare-release.yml`; see "how to install a new ch-elm ig or matchbox version"
in `README.md`. The release version is `<ch-elm>-<matchbox>` (e.g. `1.15.1-4.1.22`), for a ch-elm ci-build
`<ch-elm>-cibuild.<package date>-<matchbox>`. `release.yml` checks it against the `Dockerfile` and the IG package.
Releases up to `1.15.6` used a separate version number.

To make a release by hand, edit the files as the script does, add the changelog entry and push to `main`. Don't tag by
hand. A tag is published at once: don't move or delete it.
