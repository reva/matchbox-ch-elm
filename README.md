# matchbox-ch-elm
matchbox configured with ch-elm for validation


## how to install a new ch-elm ig or matchbox version

The `Prepare a release` workflow (`.github/workflows/prepare-release.yml`) runs every weekday. When there is a new
matchbox release or a new published ch-elm version, it opens a PR with the updated versions and the changelog entry.
Merging the PR creates the release and builds the image.

Start the workflow by hand for anything else:

- a specific matchbox version (e.g. a v4 patch when v5 is the latest): `matchbox` = `v4.1.30`
- a specific ch-elm version: `chelm` = `1.16.0`
- the current ch-elm ci-build: `chelm` = `cibuild` (released as `<version>-cibuild`, `-cibuild2`, … pre-releases)

## Build container for matchbox configured with ch-elm

```
docker build --progress=plain -t matchbox-ch-elm .
docker run -d --name matchbox-ch-elm -p 8080:80 matchbox-ch-elm
docker logs matchbox-ch-elm --follow 
```

after startup matchbox will be available at
http://localhost:8080/matchboxv3/


## Download image

From the GitHub Container registry, by release version or by `<ch-elm version>-<matchbox version>`:

```
docker run -d --name matchbox-ch-elm -p 8080:80 ghcr.io/ahdis/matchbox-ch-elm:1.15.6
docker run -d --name matchbox-ch-elm -p 8080:80 ghcr.io/ahdis/matchbox-ch-elm:1.15.1-4.1.21
```

From Google Artifact Registry (only releases made with the `gar` option of the release workflow):

```
docker run -d --name matchbox-ch-elm -p 8080:80  europe-west6-docker.pkg.dev/ahdis-ch/ahdis/matchbox-ch-elm:1.15.6
```
