#!/bin/sh
#
# vim: expandtab ts=2 :

ARGS=$*

SPHINXBUILD=sphinx-build
TMPDIR='/tmp/offlineimap-sphinx-doctrees'
WEBSITE='./website'
DOCBASE="${WEBSITE}/_doc"
DESTBASE="${DOCBASE}/versions"
VERSIONS_YML="${WEBSITE}/_data/versions.yml"
ANNOUNCES_YML="${WEBSITE}/_data/announces.yml"
ANNOUNCES_YML_TMP="${ANNOUNCES_YML}.tmp"
CONTRIB_YML="${WEBSITE}/_data/contribs.yml"
CONTRIB="${DOCBASE}/contrib"
HEADER="# DO NOT EDIT MANUALLY: it is generated by a script (website-doc.sh)."


function fix_pwd () {
  cd "$(git rev-parse --show-toplevel)" || \
    exit 2 "cannot determine the root of the repository"
  test -d "$DESTBASE" || exit 1
}

fix_pwd
version="v$(./offlineimap.py --version)"



#
# Add the doc for the contrib files.
#
function contrib () {
  echo $HEADER > "$CONTRIB_YML"
  # systemd
  cp -afv "./contrib/systemd/README.md" "${CONTRIB}/systemd.md"
  echo "- {filename: 'systemd', linkname: 'Integrate with systemd'}" >> "$CONTRIB_YML"
}



#
# Build the sphinx documentation.
#
function api () {
  # Build the doc with sphinx.
  dest="${DESTBASE}/${version}"
  echo "Cleaning target directory: $dest"
  rm -rf "$dest"
  $SPHINXBUILD -b html -d "$TMPDIR" ./docs/doc-src "$dest"

  # Build the JSON definitions for Jekyll.
  # This let know the website about the available APIs documentations.
  echo "Building Jekyll data: $VERSIONS_YML"
  # Erase previous content.
  echo "$HEADER" > "$VERSIONS_YML"
  echo "# However, it's correct to /remove/ old API docs here."
  echo "# While at it, don't forget to adjust the _doc/versions directory."
  for version in $(ls "$DESTBASE" -1 | sort -nr)
  do
    echo "- $version"
  done | sort -V >> "$VERSIONS_YML"
}



#
# Return title from release entry.
# $1: full release title
#
function parse_releases_get_link () {
  echo $1 | sed -r -e 's,^### (OfflineIMAP.*)\),\1,' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -r -e 's,[\.("],,g' \
    | sed -r -e 's, ,-,g'
}

#
# Return version from release entry.
# $1: full release title
#
function parse_releases_get_version () {
  echo $1 | sed -r -e 's,^### [a-Z]+ (v[^ ]+).*,\1,'
}

#
# Return date from release entry.
# $1: full release title
#
function parse_releases_get_date () {
  echo $1 | sed -r -e 's,.*\(([0-9]+-[0-9]+-[0-9]+).*,\1,'
}

#
# Make Changelog public and save links to them as JSON.
#
function releases () {
  # Copy the Changelogs.
  for foo in ./Changelog.md ./Changelog.maint.md
  do
    cp -afv "$foo" "$DOCBASE"
  done

  # Build the announces JSON list. Format is JSON:
  #       - {version: '<version>', link: '<link>'}
  #       - ...
  echo "$HEADER" > "$ANNOUNCES_YML"
  # Announces for the mainline.
  grep -E '^### OfflineIMAP' ./Changelog.md | while read title
  do
    link="$(parse_releases_get_link "$title")"
    v="$(parse_releases_get_version "$title")"
    d="$(parse_releases_get_date "$title")"
    echo "- {date: '${d}', version: '${v}', link: 'Changelog.html#${link}'}"
  done | tee -a "$ANNOUNCES_YML_TMP"
  # Announces for the maintenance releases.
  grep -E '^### OfflineIMAP' ./Changelog.maint.md | while read title
  do
    link="$(parse_releases_get_link "$title")"
    v="$(parse_releases_get_version "$title")"
    d="$(parse_releases_get_date "$title")"
    echo "- {date: '${d}', version: '${v}', link: 'Changelog.maint.html#${link}'}"
  done | tee -a "$ANNOUNCES_YML_TMP"
  sort -nr "$ANNOUNCES_YML_TMP" >> "$ANNOUNCES_YML"
  rm -f "$ANNOUNCES_YML_TMP"
}

function manhtml () {
  set -e

  cd ./docs
  make manhtml
  cd ..
  cp -av ./docs/manhtml/* "$DOCBASE"
}


exit_code=0
test "n$ARGS" = 'n' && ARGS='usage' # no option passed
for arg in $ARGS
do
  # PWD was fixed at the very beginning.
  case "n$arg" in
    "nreleases")
      releases
      ;;
    "napi")
      api
      ;;
    "nhtml")
      manhtml
      ;;
    "ncontrib")
      contrib
      ;;
    "nusage")
      echo "Usage: website-doc.sh <releases|api|contrib|usage>"
      ;;
    *)
      echo "unkown option $arg"
      exit_code=$(( $exit_code + 1 ))
      ;;
  esac
done

exit $exit_code
