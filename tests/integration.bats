#!/usr/bin/env bats

readonly executable="$BATS_TEST_DIRNAME/../src/bitbutler.sh"

setup()
{
    export BB_VENDOR_PATH="$BATS_TEST_DIRNAME/../src"
    export BB_CONFIG_FILE="$BATS_TEST_DIRNAME/_data/dummy.conf"
}

teardown()
{
    unset BB_CONFIG_FILE BB_VENDOR_PATH
    rm -f "$BATS_TMPDIR/test.conf"
}

@test "version option" {
    run "$executable" --version

    [[ "$status" = "0" ]]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "version command" {
    run "$executable" version

    [[ "$status" = "0" ]]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "usage" {
    run "$executable" --help

    [[ "$status" = "0" ]]
    [[ "$output" =~ 'Bitbucket management and helper tool' ]]

    run "$executable" help

    [[ "$status" = "0" ]]
    [[ "$output" =~ 'Bitbucket management and helper tool' ]]
}

@test "no vendor path" {
    BB_VENDOR_PATH=
    run "$executable" --version

    [[ "$status" = "1" ]]
    [[ "$output" =~ "Cannot open" ]]
}

@test "vendor path not a directory" {
    BB_VENDOR_PATH=not-a-directory
    run "$executable" --version

    [[ "$status" = "1" ]]
    [[ "$output" =~ "Could not find dependencies" ]]
}

@test "unknown command" {
  run "$executable" foobar

  [[ "$status" = "1" ]]
  [[ "$output" =~ 'Unknown command' ]]
}

@test "unknown option" {
  run "$executable" --foobar

  [[ "$status" = "1" ]]
  [[ "$output" =~ 'Unknown option' ]]
}

@test "cmd config - creating file" {
  BB_CONFIG_FILE="$BATS_TMPDIR/test.conf"
  run "$executable" config

  [[ "$status" = "0" ]]
  [[ "$output" =~ 'Creating a config file' ]]
  [[ "$output" =~ 'Created config file' ]]
  [[ -f "$BATS_TMPDIR/test.conf" ]]
  grep '# bitbutler configuration file' "$BATS_TMPDIR/test.conf"
  grep 'bitbucket_user=' "$BATS_TMPDIR/test.conf"
  grep 'bitbucket_pass=' "$BATS_TMPDIR/test.conf"
  grep 'bitbucket_owner=' "$BATS_TMPDIR/test.conf"
}

@test "cmd config - existing file" {
  run "$executable" config

  [[ "$status" = "0" ]]
  [[ "$output" =~ 'already exists' ]]
  [[ ! "$output" =~ 'Created config file' ]]
}
