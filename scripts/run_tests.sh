#/bin/bash

set -eu

on_exit() {
	if [ "$?" -eq 0 ]
	then
		printf '[+] OK all tests passed.\n'
		exit 0
	fi
	printf '[+] ERROR tests failed!\n'
	exit 1
}

trap on_exit EXIT

# Expect all valid snippets to pass
./lintdown.sh tests/valid_snippets.md

# Expect invalid snippets to fail
if ./lintdown.sh tests/invalid_snippets.md &>/dev/null
then
	printf 'Error: expected lint to fail but it passed!\n'
	exit 1
fi

# Extract C code from C and patch includes and wrap it in a main function
C_INCLUDES=stdio.h ./lintdown.sh tests/valid_snippets.h --wrap-main
