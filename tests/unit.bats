#!/usr/bin/env bats

setup() {
  . shellmock
  shellmock_clean

  export BB_VENDOR_PATH="$BATS_TEST_DIRNAME/../src"
  source "$BATS_TEST_DIRNAME/../src/bitbutler.sh"
}

teardown() {
  if [ -z "$TEST_FUNCTION" ]; then
    shellmock_clean
    rm -f sample.out
  fi

  unset BB_CONFIG_FILE BB_VENDOR_PATH
}

@test "checkError - non-JSON response" {
  (jq --version &>/dev/null) || skip 'jq not found'

  run checkError "Plain text"

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Plain text" ]]
}

@test "checkError - error response without details" {
  (jq --version &>/dev/null) || skip 'jq not found'

  run checkError '{"type":"error"}'

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Unknown api error" ]]
}

@test "checkError - error response with message" {
  (jq --version &>/dev/null) || skip 'jq not found'

  run checkError "$(< $BATS_TEST_DIRNAME/_data/responses/generic-error-no-details.json)"

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Something went wrong" ]]
}

@test "checkError - error response with message and details" {
  (jq --version &>/dev/null) || skip 'jq not found'

  run checkError "$(< $BATS_TEST_DIRNAME/_data/responses/generic-error.json)"

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Bad request" ]]
  [[ "$output" =~ "You must specify a valid source branch when creating a pull request" ]]
}