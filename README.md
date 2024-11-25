# lintdown.sh

Shell script to lint code snippets in markdown. Check your README.md in the CI!

All linters should just be static code analysis and the snippets are not actually executed.
Untrusted markdown files should still be handled with caution.

## Example

This go snippet is linted by this [github action](https://github.com/ChillerDragon/lintdown.sh/blob/master/.github/workflows/lintdown.yml)

```go
package main

import "fmt"

func main() {
	fmt.Print("if this is not valid go code the CI fails")
}
```

## Supported languages

### go

Needs `go` to be installed in PATH.

### lua

Needs `luacheck` to be installed in PATH.

```
luarocks install luacheck
```

### ruby

Needs `rubocop` to be installed in PATH.

```
gem install rubocop
```

## shell (bash and POSIX sh)

Needs `shellcheck` to be installed in PATH.

```
apt-get install shellcheck
```

ShellCheck supports multiple shells so it needs to know which one it is.
So make sure to either add a shebang (`#!/bin/bash`) to the first line of your snippet.
Or be specific with the markdown language annotation. Use ```\`\`\`bash``` instead of just ```\`\`\`shell```.
Otherwise it defaults to POSIX shell.


### python

It will run all linters it can find in PATH.
It will be looking for `mypy`, `pyright` and `pylint`.

### javascript

It will run all linters it can find in PATH.
It will be looking for `eslint` and `standard`.

### typescript

Needs `tsc` to be installed in PATH.
If `ts-standard` is installed it will also run that.

### C

Needs ``gcc`` to be installed in PATH.
You can also change the compiler by setting the CC environment variable
for example ``CC=clang lintdown.sh README.md``
You can also set LDFLAGS if you want to link some libraries
such as ``LDFLAGS=-lSDL lintdown.sh README.md``

## Projects using lintdown.sh

- https://github.com/teeworlds-go/protocol/ - go lang ([github action](https://github.com/teeworlds-go/protocol/blob/bee29bd3ecb6c688c07d72be66e452eac95045d6/.github/workflows/main.yml#L33-L38))
