#!/usr/bin/env bash
# Prepares the next release in the working tree: updates the matchbox base image and/or the ch-elm IG package, the
# versions in src/application.yaml and README.md, and adds the changelog entry. Changes nothing if there's nothing new.
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
package_version() { tar -xOzf "$1" package/package.json | jq -r .version; }
versions() { awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+(-cibuild[0-9]*)?$/ { print $1 }' changelog.md; }
# ch-elm versions of the releases, without the ci-builds
released_chelm() {
  awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+/ { cibuild = ($1 ~ /-cibuild/) } !cibuild && sub(/^- ch\.fhir\.ig\.ch-elm#/, "")' \
    changelog.md
}
next_patch() { IFS=. read -r X Y Z <<< "$1"; echo "$X.$Y.$((Z + 1))"; }
next_cibuild() {
  local n
  n=$(versions | awk -v p="$1-cibuild" 'index($0, p) == 1 && substr($0, length(p) + 1) ~ /^[0-9]*$/' | wc -l)
  if [ "$n" -eq 0 ]; then echo "$1-cibuild"; else echo "$1-cibuild$((n + 1))"; fi
}

CURRENT_MATCHBOX=$(sed -n 's/^FROM .*matchbox:\(v[^ ]*\).*/\1/p' Dockerfile)
CURRENT_CHELM=$(package_version "$PACKAGE")
LAST=$(versions | head -1)
RELEASED=$(versions | grep -v cibuild | sort -V | tail -1)
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
    "https://europe-west6-docker.pkg.dev/v2/ahdis-ch/ahdis/matchbox/manifests/$MATCHBOX"; then
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
    if ! cmp -s "$TMP/package.tgz" "$PACKAGE"; then
      CHELM=$(package_version "$TMP/package.tgz")
      CHELM_SOURCE=cibuild
    fi
    ;;
  "")
    PUBLISHED=$(curl -fsSL https://fhir.ch/ig/ch-elm/package-list.json \
      | jq -r '[.list[] | select(.status != "ci-build")][0].version')
    # After a ci-build, the published package of the same version replaces it, unless that version was released
    # before the ci-build (a ci-build that still has the version of the last published package)
    if newer "$PUBLISHED" "$CURRENT_CHELM" || { [[ "$LAST" == *-cibuild* ]] && [ "$PUBLISHED" = "$CURRENT_CHELM" ] &&
        ! released_chelm | grep -qxF "$PUBLISHED"; }; then
      CHELM=$PUBLISHED
      CHELM_SOURCE=published
    fi
    ;;
  *)
    if [ "$2" != "$CURRENT_CHELM" ] || [[ "$LAST" == *-cibuild* ]]; then
      CHELM=$2
      CHELM_SOURCE=published
    fi
    ;;
esac
if [ "$CHELM_SOURCE" = published ]; then
  curl -fsSL -o "$TMP/package.tgz" "https://fhir.ch/ig/ch-elm/$CHELM/package.tgz"
  if [ "$(package_version "$TMP/package.tgz")" != "$CHELM" ]; then
    echo "The package of ch-elm $CHELM has the version $(package_version "$TMP/package.tgz")" >&2
    exit 1
  fi
fi

if [ "$MATCHBOX" = "$CURRENT_MATCHBOX" ] && [ -z "$CHELM_SOURCE" ]; then
  echo "Nothing to release: matchbox $CURRENT_MATCHBOX and ch-elm $CURRENT_CHELM are current" >&2
  exit 0
fi

# The version follows the ch-elm version. If that's taken (or older than the last release), the patch is increased.
# A ci-build is a pre-release of that version.
if newer "$CHELM" "$RELEASED"; then BASE=$CHELM; else BASE=$(next_patch "$RELEASED"); fi
if [ "$CHELM_SOURCE" = cibuild ]; then
  VERSION=$(next_cibuild "$BASE")
elif [ -z "$CHELM_SOURCE" ] && [[ "$LAST" == *-cibuild* ]]; then
  VERSION=$(next_cibuild "${LAST%-cibuild*}")
else
  VERSION=$BASE
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
ENTRY=$(printf '%s %s\n- matchbox %s\n- ch.fhir.ig.ch-elm#%s\n' "$VERSION" "$(date +%Y/%m/%d)" "$MATCHBOX" "$CHELM")
{ printf '%s\n\n' "$ENTRY"; cat changelog.md; } > changelog.md.tmp && mv changelog.md.tmp changelog.md
if [[ "$VERSION" != *-cibuild* ]]; then
  replace "s|\(ghcr\.io/ahdis/matchbox-ch-elm:\)[0-9.]*$|\1$VERSION|" README.md
  replace "s|\(ghcr\.io/ahdis/matchbox-ch-elm:\)[0-9.]*-[0-9.]*$|\1$CHELM-${MATCHBOX#v}|" README.md
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
