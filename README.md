# matchbox-ch-elm
matchbox configured with ch-elm for validation


## how to install a new ch-elm ig or matchbox version

The `Prepare a release` workflow (`.github/workflows/prepare-release.yml`) runs every weekday. When there is a new
matchbox release or a new published ch-elm version, it opens a PR with the updated versions and the changelog entry.
Before merging, check whether `src/application.yaml` needs changes for the new versions and push them to the PR
branch. Merging the PR creates the release and builds the image. A scheduled run doesn't replace a release PR that has
changes by someone else.

Start the workflow by hand for anything else:

- a specific matchbox version (e.g. a v4 patch when v5 is the latest): `matchbox` = `v4.1.30`
- a specific ch-elm version: `chelm` = `1.16.0`
- the current ch-elm ci-build: `chelm` = `cibuild`

A release is named `<ch-elm version>-<matchbox version>`, e.g. `1.15.1-4.1.22`. A ch-elm ci-build is a pre-release
named `<ch-elm version>-cibuild.<package date>-<matchbox version>`, e.g. `1.16.0-cibuild.20261013132147-4.1.22`, with
the additional image tag `1.16.0-cibuild-4.1.22` for the latest ci-build of that combination.

## Build container for matchbox configured with ch-elm

```
docker build --progress=plain -t matchbox-ch-elm .
docker run -d --name matchbox-ch-elm -p 8080:80 matchbox-ch-elm
docker logs matchbox-ch-elm --follow 
```

after startup matchbox will be available at
http://localhost:8080/matchboxv3/


## Download image

From the GitHub Container registry, by `<ch-elm version>-<matchbox version>` or by ch-elm version (the latest build
for it):

```
docker run -d --name matchbox-ch-elm -p 8080:80 ghcr.io/ahdis/matchbox-ch-elm:1.15.1-4.1.21
docker run -d --name matchbox-ch-elm -p 8080:80 ghcr.io/ahdis/matchbox-ch-elm:1.15.1
```

From Google Artifact Registry:

```
docker run -d --name matchbox-ch-elm -p 8080:80  europe-west6-docker.pkg.dev/ahdis-ch/ahdis/matchbox-ch-elm:1.15.6
```
