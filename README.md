# lintdown.sh

Shell script to lint code snippets in markdown. Check your README.md in the CI!

## Supported languages

- go

## Example

This go snippet is linted by this [github action](https://github.com/ChillerDragon/lintdown.sh/blob/master/.github/workflows/lintdown.yml)

```go
package main

func main() {
    if this is not valid go code the CI fails
}
```

## supported languages

### go

Needs `go` to be installed in PATH.

### lua

Needs `luacheck` to be installed in PATH.

```
luarocks install luacheck
```

