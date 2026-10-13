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
| `.github/workflows/release.yml` | `Create a release`, started by hand with a version: creates the tag and the GitHub release with the notes from `changelog.md`, then starts `build.yml` on the tag (passing the `gar` and `zulip` options) |
| `.github/workflows/build.yml` | on every pushed tag (or started by `release.yml`), builds the image (amd64 and arm64) and pushes it to `ghcr.io/ahdis/matchbox-ch-elm` as `<tag>` and the tags of `.github/scripts/version.sh --tags`; also to Google Artifact Registry and posts to Zulip (`#matchbox`), unless `gar` / `zulip` are turned off |
| `.github/scripts/version.sh` | prints the version of the image in the working tree (`<ch-elm>-<matchbox>`, for a ci-build `<ch-elm>-cibuild.<package date>-<matchbox>`), with `--tags` also the tag of its latest build |

## Release process

The release procedure (version, matchbox and ch-elm update, changelog, release workflow, image build) is in the Claude Code skill
[`.claude/skills/release/SKILL.md`](.claude/skills/release/SKILL.md). Follow it for a release.
