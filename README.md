# bitbutler

[![CircleCI](https://circleci.com/gh/particleflux/bitbutler.svg?style=shield&circle-token=74c58ba45e830a2ad198901aeabdd26224296412)](https://circleci.com/gh/particleflux/bitbutler)
[![Test Coverage](https://api.codeclimate.com/v1/badges/ab50914097740e4e3fad/test_coverage)](https://codeclimate.com/github/particleflux/bitbutler/test_coverage)
[![made-with-bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

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

**NOTE:** The bash completion script needs the *bitbutler* executable within
the `PATH`.

## Usage

There is a short overview of available commands built-in and accessible via
`bitbutler help`. For a more extensive documentation, consult the included
manpage.

## Configuration

Run `bitbutler config` to write a default configuration. You should [create a
restricted app password](https://bitbucket.org/account/settings/app-passwords/new)
instead of using your actual password which has full access to your account.
Depending on what you want to with bitbutler, different scopes are required, see
table below.

| Bitbutler command | required scope | Name the bitbucket GUI |
|:---|:---|:---|
| authtest | account | Account / Read (implies Email) |
| branches | repository | Repositories / Read |
| deploykey add | repository | Repositories / Read |
| | repository:admin | Repositories / Admin |
| deploykey delete | repository | Repositories / Read |
| | repository:admin | Repositories / Admin |
| deploykey list | repository | Repositories / Read |
| | repository:admin | Repositories / Admin |
| repo add | repository:admin | Repositories / Admin |
| repo delete | repository:delete | Repositories / Delete |
| repo list | repository | Repositories / Read |
| restriction add | repository:admin | Repositories / Admin |
| restriction delete | repository:admin | Repositories / Admin |
| restriction list | repository:admin | Repositories / Admin |
| reviewer add | repository:admin | Repositories / Admin |
| reviewer delete | repository:admin | Repositories / Admin |
| reviewer list | pullrequest | Pull requests / Read
| webhook add | webhook | Webhooks / Read and write |
| webhook delete | webhook | Webhooks / Read and write |
| webhook list | webhook | Webhooks / Read and write |

## Development

### Requirements

* [bats] and [shellmock] for running tests
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
[shellmock]: https://github.com/capitalone/bash_shell_mock
