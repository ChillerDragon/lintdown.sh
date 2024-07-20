# lintdown.sh

Shell script to lint code snippets in markdown. Check your README.md in the CI!

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

