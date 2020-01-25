#!/usr/bin/env bats

readonly executable="$BATS_TEST_DIRNAME/../src/bitbutler.sh"

setup()
{
    export BB_VENDOR_PATH="$BATS_TEST_DIRNAME/../src"
    export BB_CONFIG_FILE="$BATS_TEST_DIRNAME/_data/empty.conf"
}

teardown()
{
    unset BB_CONFIG_FILE BB_VENDOR_PATH
}

@test "version" {
    run "$executable" --version

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