#!/bin/bash

set -ueo pipefail
IFS=$'\n\t'

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

lint_failed() {
	local snippet="$1"
	err "linter failed on $(basename "$snippet") check the errors above"
	err "snippet content:"
	cat "$snippet" 1>&2
	exit 1
}

gen_snippets() {
	local markdown_file="$1"
	local markdown_lang="$2"
	local lang_extension="${3:-$markdown_lang}"

	local in_snippet=0
	local snippet_num=0
	local snippet_path="invalid_snippet.txt"

	while IFS='' read -r line
	do
		if [[ "$line" =~ ^\`\`\`$markdown_lang$ ]]
		then
			snippet_path="$TMP_DIR/readme_snippet_${snippet_num}.${lang_extension}"
			:>"$snippet_path"
			snippet_num="$((snippet_num + 1))"
			in_snippet=1
			continue
		fi
		if [ "$line" == '```' ] && [ "$in_snippet" == 1 ]
		then
			in_snippet=0
		fi
		[ "$in_snippet" = 1 ] || continue

		cat <<< "$line" >> "$snippet_path"
	done < "$markdown_file"
}

lint_go_snippets() {
	local markdown_file="$1"
	gen_snippets "$markdown_file" go

	for snippet in "$TMP_DIR"/readme_snippet_*.go; do
		[ -f "$snippet" ] || continue

		log "building $snippet ..."
		go build -v -o tmp/tmp "$snippet" || lint_failed "$snippet"
	done

	for snippet in "$TMP_DIR"/readme_snippet_*.go; do
		[ -f "$snippet" ] || continue

		log "checking format $snippet ..."
		if ! diff -u <(echo -n) <(gofmt -d "$snippet"); then
			lint_failed "$snippet"
		fi
	done
}

lint_lua_snippets() {
	local markdown_file="$1"
	gen_snippets "$markdown_file" lua

	for snippet in "$TMP_DIR"/readme_snippet_*.lua; do
		[ -f "$snippet" ] || continue

		log "checking $snippet ..."
		luacheck "$snippet" || lint_failed "$snippet"
	done
}

lint_ruby_snippets() {
	local markdown_file="$1"
	local snippet
	gen_snippets "$markdown_file" ruby rb

	for snippet in "$TMP_DIR"/readme_snippet_*.rb; do
		[ -f "$snippet" ] || continue

		log "checking $snippet ..."
		rubocop --except Style/FrozenStringLiteralComment "$snippet" || lint_failed "$snippet"
	done
}

add_shell_shebang() {
	local snippet="$1"
	if grep -q '^#!/' "$snippet"
	then
		return
	fi
	log "no shebang found patching /bin/sh shebang ..."
	sed '1s/^/#!\/bin\/sh\n/' "$snippet" > "$snippet".tmp
	mv "$snippet".tmp "$snippet"
}

lint_shell_snippets() {
	local markdown_file="$1"
	local snippet
	gen_snippets "$markdown_file" shell sh
	gen_snippets "$markdown_file" bash bash
	gen_snippets "$markdown_file" sh sh

	for snippet in "$TMP_DIR"/readme_snippet_*.sh; do
		[ -f "$snippet" ] || continue

		log "checking $snippet ..."
		add_shell_shebang "$snippet"
		shellcheck "$snippet" || lint_failed "$snippet"
	done

	for snippet in "$TMP_DIR"/readme_snippet_*.bash; do
		[ -f "$snippet" ] || continue

		log "checking $snippet ..."
		shellcheck "$snippet" || lint_failed "$snippet"
	done
}

try_linters() {
	local snippet="$1"
	shift
	local linter
	for linter in "$@"
	do
		[ -x "$(command -v "$linter")" ] || continue
		log "found $linter"

		"$linter" "$snippet" || lint_failed "$snippet"
	done
}

lint_python_snippets() {
	local markdown_file="$1"
	local snippet
	gen_snippets "$markdown_file" py
	gen_snippets "$markdown_file" python py
	gen_snippets "$markdown_file" python3 py
	gen_snippets "$markdown_file" python2 py

	for snippet in "$TMP_DIR"/readme_snippet_*.py; do
		[ -f "$snippet" ] || continue

		log "checking $snippet ..."
		try_linters "$snippet" pylint mypy pyright
	done
}

lint_javascript_snippets() {
	local markdown_file="$1"
	local snippet
	gen_snippets "$markdown_file" js
	gen_snippets "$markdown_file" javascript js
	gen_snippets "$markdown_file" JavaScript js
	gen_snippets "$markdown_file" node js

	for snippet in "$TMP_DIR"/readme_snippet_*.js; do
		[ -f "$snippet" ] || continue

		log "checking $snippet ..."
		try_linters "$snippet" eslint standard
	done
}

lint_typescript_snippets() {
	local markdown_file="$1"
	local snippet
	gen_snippets "$markdown_file" typescript ts
	gen_snippets "$markdown_file" TypeScript ts

	for snippet in "$TMP_DIR"/readme_snippet_*.ts; do
		[ -f "$snippet" ] || continue

		log "building $snippet ..."
		tsc "$snippet" || lint_failed "$snippet"
	done

	for snippet in "$TMP_DIR"/readme_snippet_*.ts; do
		[ -f "$snippet" ] || continue

		log "linting $snippet ..."
		try_linters "$snippet" ts-standard
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
lint_ruby_snippets "$file"
lint_shell_snippets "$file"
lint_python_snippets "$file"
lint_javascript_snippets "$file"
lint_typescript_snippets "$file"

