#!/usr/bin/env bats

setup() {
  if ! hash shellmock; then
    skip 'shellmock not installed'
  fi

  . shellmock
  shellmock_clean

  export BB_VENDOR_PATH="$BATS_TEST_DIRNAME/../src"
  export BB_CONFIG_FILE="$BATS_TEST_DIRNAME/_data/dummy.conf"

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

@test "_request - basic parameters" {
  shellmock_expect curl --type partial --match '-X GET' --status 0
  run _request GET /foo

  [[ "$status" = "0" ]]

  shellmock_verify
  [[ "${capture[0]}" =~ "curl-stub -s -X GET -H Accept: application/json -H Content-Type: application/json -u dummy:super-secret-password" ]]

}

@test "_request - GET" {
  shellmock_expect curl --type partial --match '-X GET' --status 0 --output 'hello'
  run _request GET /foo

  [[ "$status" = "0" ]]
  [[ "$output" = "hello" ]]

  shellmock_verify
  [[ "${capture[0]}" =~ "curl-stub -s -X GET" ]]
}

@test "_request - POST (no body)" {
  shellmock_expect curl --type partial --match '-X POST' --status 0 --output 'bar'
  run _request POST /bar

  [[ "$status" = "0" ]]
  [[ "$output" = "bar" ]]

  shellmock_verify
  [[ "${capture[0]}" =~ "curl-stub -s -X POST" ]]
}

@test "_request - POST" {
  shellmock_expect curl --type partial --match '-X POST' --status 0 --output 'abc'
  run _request POST /abc "post-content"

  [[ "$status" = "0" ]]
  [[ "$output" = "abc" ]]

  shellmock_verify
  [[ "${capture[0]}" =~ "curl-stub -s -X POST" ]]
  [[ "${capture[0]}" =~ "-d post-content" ]]
}

@test "open - fallback page" {
  shellmock_expect xdg-open --type partial --match '/dashboard/' --status 0
  run open

  [[ "$status" = "0" ]]
  shellmock_verify
  [[ "${capture[0]}" =~ "xdg-open-stub" ]]
}

@test "open - dashboard" {
  shellmock_expect xdg-open --type partial --match '/dashboard/' --status 0
  run open dashboard

  [[ "$status" = "0" ]]
  shellmock_verify
  [[ "${capture[0]}" = "xdg-open-stub"* ]]
}

@test "open - apidoc" {
  shellmock_expect xdg-open --type partial --match 'https://developer.atlassian.com' --status 0
  run open apidoc

  [[ "$status" = "0" ]]
  shellmock_verify
  [[ "${capture[0]}" = "xdg-open-stub https://developer.atlassian.com"* ]]
}

@test "open - unknown page" {
  run open unknown-stuff

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Unknown page given" ]]
}

@test "authtest - success" {
  shellmock_expect curl \
    --type partial \
    --match '/user' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/user.json)"

  run authtest

  [[ "$status" = "0" ]]
  [[ "$output" =~ "logged in as \"dummy\"" ]]
}

@test "authtest - failure" {
  shellmock_expect curl \
    --type partial \
    --match '/user' \
    --status 0 \
    --output ""

  run authtest

  [[ "$status" = "0" ]]
  [[ "$output" =~ "authentication failed" ]]
}

@test "branches - missing arguments" {
  run branches

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Required argument" ]]
}

@test "branches - success" {
  shellmock_expect curl \
    --type partial \
    --match 'dummy-repo/refs' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/branches.json)"

  run branches dummy-repo

  [[ "$status" = "0" ]]
  [[ "${lines[0]}" = "ISSUE-123" ]]
  [[ "${lines[1]}" = "develop" ]]
  [[ "${lines[2]}" = "master" ]]
  [[ "${lines[3]}" = "test" ]]
}

@test "branches - failure" {
  shellmock_expect curl \
    --type partial \
    --match 'foo/refs' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/error-repo-not-found.json)"

  run branches foo

  [[ "$status" = "1" ]]
  [[ "${lines[0]}" =~ "Repository dummy/foo not found" ]]
}
