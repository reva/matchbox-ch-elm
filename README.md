# matchbox-ch-elm
matchbox configured with ch-elm for validation


## how to install a new ch-elm ig or matchbox version

See the release procedure in [`.claude/skills/release/SKILL.md`](.claude/skills/release/SKILL.md) (or ask Claude Code
to make a release). You get a message on Zulip when the new matchbox-ch-elm image is available in the registry.

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

From Google Artifact Registry (only releases made with the `gar` option of the release workflow):

```
docker run -d --name matchbox-ch-elm -p 8080:80  europe-west6-docker.pkg.dev/ahdis-ch/ahdis/matchbox-ch-elm:1.15.6
```
