# bitbutler

A bitbucket administration utility.

## Runtime requirements

* bash
* curl
* [jq]

## Installation

```
sudo make install
```

By default, the makefile installs to `/usr/local` prefix. This can be overridden
with the usual variables `PREFIX` and `DESTDIR`. For example, to install to
~/.local, run `make PREFIX=$HOME/.local`.

## Bash completion

For bash completion, source the included `bitbutler.completion` file anywhere in
bash, for example in your `.bashrc`:

```bash
# append to .bashrc
. path/to/bitbutler.completion
```

**NOTE:** The bash completion script needs the *bitbutler* binary within your
`PATH`.

## Development

### Requirements

* [bats] for running tests
* [kcov] for generating code coverage
* [asciidoc] for generating the man page

### Running tests

```
make test
```

Or, with coverage:

```
make coverage
```

[jq]: https://stedolan.github.io/jq/
[bats]: https://github.com/bats-core/bats-core
[kcov]: https://github.com/SimonKagstrom/kcov
[asciidoc]: http://asciidoc.org/
