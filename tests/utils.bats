#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../src/utils.sh"

@test "utils log function" {
    result=$(l "Hello World")
    [ "$result" = "Hello World" ]

    result=$(l "\e[01;31merror\e[0m")
    [ "$result" = "$(echo -e '\e[01;31merror\e[0m')" ]
}

@test "utils v function" {
    run v "Hello World"

    [[ "$status" -eq 1 ]]
    [[ -z "$output" ]]

    verbose=1
    run v "Hello World"

    [[ "$status" -eq 0 ]]
    [[ "$output" = "Hello World" ]]
}

@test "utils error log function" {
    # no output to stdout
    result=$(e "total error")
    [ "$result" = "" ]

    # instead to stderr
    result=$(e "total error" 2>&1)
    [ "$result" = "$(echo -e '\e[31mtotal error\e[0m')" ]
}

@test "utils die function" {
    run die "total error"
    [ "$output" = "$(echo -e '\e[31mtotal error\e[0m')" ]
    [ "$status" -eq 1 ]
}

@test "beginsWith" {
    beginsWith "hello world" "hello"
    ! beginsWith "hello world" "world"
    ! beginsWith "asdf hello world" "hello"
}