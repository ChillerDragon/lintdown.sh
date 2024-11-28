#!/bin/bash

set -ueo pipefail
IFS=$'\n\t '

# You can set any of those environment variables
# if you want to want something other than the defaults

# for C
# https://www.gnu.org/software/make/manual/html_node/Implicit-Variables.html
CC="${CC:-gcc}"
LDFLAGS="${LDFLAGS:-}"
LDLIBS="${LDLIBS:-}"
CFLAGS="${CLFAGS:-}"

# for python
# shellcheck disable=SC2034
PYLINT_ARGS=${PYLINT_ARGS:---disable=W0105,C0301}

# for shell (bash/posix)
# shellcheck disable=SC2034
SHELLCHECK_ARGS=${SHELLCHECK_ARGS:--e 'SC1091,SC2164'}

# for ruby
# shellcheck disable=SC2034
RUBOCOP_ARGS=${RUBOCOP_ARGS:---except Style/FrozenStringLiteralComment,Lint/ScriptPermission}

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

# run_linter_or_die [linter] [snippet]
run_linter_or_die() {
	local linter="$1"
	local snippet="$2"

	local linter_args_var
	linter_args_var="${linter^^}_ARGS"
	# might be undefined
	# but expands for example
	#
	# PYLINT_ARGS
	set +u
	local linter_args=${!linter_args_var}
	set -u

	# shellcheck disable=SC2086
	"$linter" $linter_args "$snippet" || lint_failed "$snippet"
}

try_linters() {
	local snippet="$1"
	shift
	local linter
	for linter in "$@"
	do
		[ -x "$(command -v "$linter")" ] || continue
		log "found $linter"

		run_linter_or_die "$linter" "$snippet"
	done
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

lint_c_snippets() {
	local markdown_file="$1"
	gen_snippets "$markdown_file" c c
	gen_snippets "$markdown_file" C c

	for snippet in "$TMP_DIR"/readme_snippet_*.c; do
		[ -f "$snippet" ] || continue

		log "building $snippet ..."
		# shellcheck disable=2086
		"$CC" $CFLAGS "$snippet" -o "$TMP_DIR"/tmp $LDFLAGS $LDLIBS || lint_failed "$snippet"
	done
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
		run_linter_or_die luacheck "$snippet"
	done
}

lint_ruby_snippets() {
	local markdown_file="$1"
	local snippet
	gen_snippets "$markdown_file" ruby rb

	for snippet in "$TMP_DIR"/readme_snippet_*.rb; do
		[ -f "$snippet" ] || continue

		log "checking $snippet ..."
		run_linter_or_die rubocop "$snippet"
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
		run_linter_or_die shellcheck "$snippet"
	done

	for snippet in "$TMP_DIR"/readme_snippet_*.bash; do
		[ -f "$snippet" ] || continue

		log "checking $snippet ..."
		run_linter_or_die shellcheck "$snippet"
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

		log "compiling $snippet ..."
		python -m compileall "$snippet"  || lint_failed "$snippet"
	done

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
		run_linter_or_die tsc "$snippet"
	done

	for snippet in "$TMP_DIR"/readme_snippet_*.ts; do
		[ -f "$snippet" ] || continue

		log "linting $snippet ..."
		try_linters "$snippet" ts-standard
	done
}

usage() {
	printf "usage: lintdown.sh FILENAME..\n" 1>&2
}

if [ "${1:-}" = "" ]
then
	usage
	exit 1
fi

lint_file() {
	file="$1"
	if [ ! -f "$file" ]
	then
		err "file not found '$file'"
		exit 1
	fi

	lint_c_snippets "$file"
	lint_go_snippets "$file"
	lint_lua_snippets "$file"
	lint_ruby_snippets "$file"
	lint_shell_snippets "$file"
	lint_python_snippets "$file"
	lint_javascript_snippets "$file"
	lint_typescript_snippets "$file"
}

main() {
	local markdown_files=()
	local arg
	while true
	do
		[ "$#" -gt 0 ] || break
		arg="$1"
		shift

		if [ "${arg::1}" = '-' ]
		then
			if [ "$arg" == "-h" ] || [ "$arg" == "--help" ]
			then
				usage
				exit 0
			else
				err "Unknown argument '$arg'"
			fi
		else
			markdown_files+=("$arg")
		fi
	done

	if [ "${#markdown_files[@]}" = "0" ]
	then
		usage
		exit 1
	fi

	local markdown_file
	for markdown_file in "${markdown_files[@]}"
	do
		lint_file "$markdown_file"
	done
}

main "$@"

