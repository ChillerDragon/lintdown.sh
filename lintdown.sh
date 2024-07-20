#!/bin/bash

set -euo pipefail

gen_snippets() {
	local markdown_file="$1"
	local markdown_lang="$2"
	local lang_extension="${3:-$markdown_lang}"

	mkdir -p tmp
	awk '/^```'"$markdown_lang"'$/ {p=1}; p; /^```$/ {p=0;print"--- --- ---"}' "$markdown_file" |
		grep -vE '^```('"$markdown_lang"')?$' |
		csplit \
		-z -s - '/--- --- ---/' \
		'{*}' \
		--suppress-matched \
		-f tmp/readme_snippet_ -b '%02d.'"$lang_extension"
}

lint_go_snippets() {
	local markdown_file="$1"
	gen_snippets "$markdown_file" go

	for snippet in ./tmp/readme_snippet_*.go; do
		[ -f "$snippet" ] || continue

		echo "building $snippet ..."
		go build -v -o tmp/tmp "$snippet" || exit 1
	done

	for snippet in ./tmp/readme_snippet_*.go; do
		[ -f "$snippet" ] || continue

		echo "checking format $snippet ..."
		if ! diff -u <(echo -n) <(gofmt -d "$snippet"); then
			exit 1
		fi
	done
}

lint_lua_snippets() {
	local markdown_file="$1"
	gen_snippets "$markdown_file" lua

	for snippet in ./tmp/readme_snippet_*.lua; do
		[ -f "$snippet" ] || continue

		echo "checking $snippet ..."
		luacheck "$snippet" || exit 1
	done
}

if [ "$1" = "" ]
then
	echo "usage: lintdown.sh FILENAME"
	exit 1
fi

file="$1"
if [ ! -f "$file" ]
then
	echo "error file not found '$file'"
	exit 1
fi

lint_go_snippets "$file"
lint_lua_snippets "$file"

