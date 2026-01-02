#/bin/bash

set -eu

# Expect all valid snippets to pass
./lintdown.sh tests/valid_snippets.md

# Expect invalid snippets to fail
if ./lintdown.sh tests/invalid_snippets.md &>/dev/null
then
	printf 'Error: expected lint to fail but it passed!\n'
	exit 1
fi

printf '[+] OK all tests passed.\n'
