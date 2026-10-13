#!/usr/bin/env bash
# Prepares the next release in the working tree: updates the matchbox base image and/or the ch-elm IG package, the
# versions in src/application.yaml and README.md, and adds the changelog entry. Changes nothing if there's nothing new.
#
# The release version is the one of .github/scripts/version.sh.
#
# Usage: prepare-release.sh [matchbox] [chelm]
#   matchbox  matchbox tag, e.g. v4.1.22. Default: the latest ahdis/matchbox release, if newer than the current one.
#   chelm     ch-elm version, e.g. 1.15.2, or 'cibuild' for the current ci-build.
#             Default: the latest published version, if newer than the current one.
#
# Writes 'version' and 'notes' to $GITHUB_OUTPUT if it's set.
set -euo pipefail
cd "$(dirname "$0")/../.."

PACKAGE=src/ch.fhir.ig.ch-elm.tgz

# sed without -i, which differs between GNU and BSD
replace() { sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }
# true if version $1 > version $2
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }
package_field() { tar -xOzf "$1" package/package.json | jq -r ".$2"; }
is_cibuild() { [[ "$(package_field "$1" url)" == *build.fhir.org* ]]; }

MATCHBOX_IMAGE=$(sed -n 's/^FROM \([^:]*\):.*/\1/p' Dockerfile)
CURRENT_MATCHBOX=$(sed -n 's/^FROM .*matchbox:\(v[^ ]*\).*/\1/p' Dockerfile)
CURRENT_CHELM=$(package_field "$PACKAGE" version)
PUBLISHED_LIST=$(curl -fsSL https://fhir.ch/ig/ch-elm/package-list.json \
  | jq -r '.list[] | select(.status != "ci-build") | .version')
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# matchbox
MATCHBOX=${1:-}
if [ -z "$MATCHBOX" ]; then
  MATCHBOX=$(gh release view --repo ahdis/matchbox --json tagName -q .tagName)
  newer "${MATCHBOX#v}" "${CURRENT_MATCHBOX#v}" || MATCHBOX=$CURRENT_MATCHBOX
fi
if [ "$MATCHBOX" != "$CURRENT_MATCHBOX" ] && ! curl -fsI -o /dev/null \
    -H "Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json" \
    "https://${MATCHBOX_IMAGE%%/*}/v2/${MATCHBOX_IMAGE#*/}/manifests/$MATCHBOX"; then
  echo "The matchbox image $MATCHBOX isn't available yet" >&2
  [ -n "${1:-}" ] && exit 1
  MATCHBOX=$CURRENT_MATCHBOX
fi

# ch-elm: CHELM_SOURCE is published, cibuild or empty (unchanged)
CHELM=$CURRENT_CHELM
CHELM_SOURCE=
case "${2:-}" in
  cibuild)
    curl -fsSL -o "$TMP/package.tgz" https://build.fhir.org/ig/ahdis/ch-elm/package.tgz
    CHELM=$(package_field "$TMP/package.tgz" version)
    # A ci-build right after a publication still has the published version, it's the same IG
    if grep -qxF "$CHELM" <<< "$PUBLISHED_LIST"; then
      echo "The ch-elm ci-build has the published version $CHELM, there is no newer ci-build" >&2
      exit 1
    fi
    if ! cmp -s "$TMP/package.tgz" "$PACKAGE"; then
      CHELM_SOURCE=cibuild
    fi
    ;;
  *)
    TARGET=${2:-$(head -1 <<< "$PUBLISHED_LIST")}
    # By default never an older version. A ci-build is replaced by the published package of the same version.
    if { [ -n "${2:-}" ] || ! newer "$CURRENT_CHELM" "$TARGET"; } &&
        { [ "$TARGET" != "$CURRENT_CHELM" ] || is_cibuild "$PACKAGE"; }; then
      CHELM=$TARGET
      CHELM_SOURCE=published
    fi
    ;;
esac
if [ "$CHELM_SOURCE" = published ]; then
  curl -fsSL -o "$TMP/package.tgz" "https://fhir.ch/ig/ch-elm/$CHELM/package.tgz"
  if [ "$(package_field "$TMP/package.tgz" version)" != "$CHELM" ]; then
    echo "The package of ch-elm $CHELM has the version $(package_field "$TMP/package.tgz" version)" >&2
    exit 1
  fi
fi

if [ "$MATCHBOX" = "$CURRENT_MATCHBOX" ] && [ -z "$CHELM_SOURCE" ]; then
  echo "Nothing to release: matchbox $CURRENT_MATCHBOX and ch-elm $CURRENT_CHELM are current" >&2
  exit 0
fi

if [ "$MATCHBOX" != "$CURRENT_MATCHBOX" ]; then
  replace "s|^\(FROM .*matchbox:\)$CURRENT_MATCHBOX|\1$MATCHBOX|" Dockerfile
fi
if [ -n "$CHELM_SOURCE" ]; then
  mv "$TMP/package.tgz" "$PACKAGE"
  replace "s/^\(        version: \)${CURRENT_CHELM//./\\.}$/\1$CHELM/" src/application.yaml
  replace "s/ch\.fhir\.ig\.ch-elm#${CURRENT_CHELM//./\\.}/ch.fhir.ig.ch-elm#$CHELM/" src/application.yaml
  if [ "$(grep -c -e "version: $CHELM$" -e "ch.fhir.ig.ch-elm#$CHELM$" src/application.yaml)" -ne 2 ]; then
    echo "Couldn't set ch-elm $CHELM in both places of src/application.yaml" >&2
    exit 1
  fi
fi

VERSION=$(.github/scripts/version.sh)
if awk '{ print $1 }' changelog.md | grep -qxF "$VERSION"; then
  echo "$VERSION is already released" >&2
  exit 1
fi

ENTRY=$(printf '%s %s\n- matchbox %s\n- ch.fhir.ig.ch-elm#%s\n' "$VERSION" "$(date +%Y/%m/%d)" "$MATCHBOX" "$CHELM")
{ printf '%s\n\n' "$ENTRY"; cat changelog.md; } > changelog.md.tmp && mv changelog.md.tmp changelog.md
if [[ "$VERSION" != *-cibuild* ]]; then
  replace "s|\(ghcr\.io/ahdis/matchbox-ch-elm:\)[0-9.]*-[0-9.]*$|\1$VERSION|" README.md
  replace "s|\(ghcr\.io/ahdis/matchbox-ch-elm:\)[0-9.]*$|\1$CHELM|" README.md
fi

echo "$ENTRY" >&2
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "version=$VERSION"
    echo "notes<<EOF"
    [ "$MATCHBOX" = "$CURRENT_MATCHBOX" ] || echo "- matchbox $CURRENT_MATCHBOX → $MATCHBOX"
    [ -z "$CHELM_SOURCE" ] || echo "- ch.fhir.ig.ch-elm $CURRENT_CHELM → $CHELM ($CHELM_SOURCE)"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
fi
