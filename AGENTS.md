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
| `.github/workflows/release.yml` | `Create a release`, started by hand on `main`: prepares the release with `prepare-release.sh`, builds the image, pushes the release commit, creates the tag and the GitHub release and starts `build.yml` on the tag |
| `.github/scripts/prepare-release.sh` | updates the files to a new matchbox and/or ch-elm version, names the release and adds the changelog entry |
| `.github/workflows/build.yml` | on every pushed tag (or started by `release.yml`), builds the image for amd64 and arm64 on native runners with Docker's reusable workflow `docker/github-builder` and pushes the multi-platform image to `ghcr.io/ahdis/matchbox-ch-elm` as `<tag>` and the tags of `.github/scripts/version.sh --tags`, and posts to Zulip (`#matchbox`), unless `zulip` is turned off. Up to `1.15.1-cibuild` it also pushed to Google Artifact Registry |
| `.github/scripts/version.sh` | reads the matchbox and ch-elm versions of the working tree: prints the release name, with `--tags` the image tags, with `--env` the versions and whether it's a pre-release |

## Release process

See "how to install a new ch-elm ig or matchbox version" in `README.md`. To follow a release:

```bash
gh run list --repo ahdis/matchbox-ch-elm --limit 2               # 'Create a release', then the build on the tag
gh run watch <id> --repo ahdis/matchbox-ch-elm --exit-status
```
