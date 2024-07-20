#!/bin/bash

set -euo pipefail

err() {
	printf '[lintdown.sh][-] %s\n' "$1" 1>&2
}
log() {
	printf '[lintdown.sh][*] %s\n' "$1"
}

if ! TMP_DIR="$(mktemp -d "/tmp/lintdown_sh_${USER}_XXXXXXXX")"
then
	err "failed to mktemp"
	exit 1
fi
if [ ! -d "$TMP_DIR" ]
then
	err "failed to create temp directory $TMP_DIR"
	exit 1
fi

cleanup() {
	rm -rf "$TMP_DIR"
}

trap cleanup EXIT

gen_snippets() {
	local markdown_file="$1"
	local markdown_lang="$2"
	local lang_extension="${3:-$markdown_lang}"

	awk '/^```'"$markdown_lang"'$/ {p=1}; p; /^```$/ {p=0;print"--- --- ---"}' "$markdown_file" |
		grep -vE '^```('"$markdown_lang"')?$' |
		csplit \
		-z -s - '/--- --- ---/' \
		'{*}' \
		--suppress-matched \
		-f "$TMP_DIR/readme_snippet_" -b '%02d.'"$lang_extension"
}

lint_go_snippets() {
	local markdown_file="$1"
	gen_snippets "$markdown_file" go

	for snippet in "$TMP_DIR"/readme_snippet_*.go; do
		[ -f "$snippet" ] || continue

		log "building $snippet ..."
		go build -v -o tmp/tmp "$snippet" || exit 1
	done

	for snippet in "$TMP_DIR"/readme_snippet_*.go; do
		[ -f "$snippet" ] || continue

		log "checking format $snippet ..."
		if ! diff -u <(echo -n) <(gofmt -d "$snippet"); then
			exit 1
		fi
	done
}

lint_lua_snippets() {
	local markdown_file="$1"
	gen_snippets "$markdown_file" lua

	for snippet in "$TMP_DIR"/readme_snippet_*.lua; do
		[ -f "$snippet" ] || continue

		log "checking $snippet ..."
		luacheck "$snippet" || exit 1
	done
}

if [ "${1:-}" = "" ]
then
	printf "usage: lintdown.sh FILENAME\n" 1>&2
	exit 1
fi

file="$1"
if [ ! -f "$file" ]
then
	err "file not found '$file'"
	exit 1
fi

lint_go_snippets "$file"
lint_lua_snippets "$file"

