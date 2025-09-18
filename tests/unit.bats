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

@test "deploykey - list" {
  shellmock_expect curl \
    --type partial \
    --match 'dummy-repo/deploy-keys' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/deploykey-list.json)"

  run deploykey list dummy-repo

  [[ "$status" = "0" ]]
  [[ "${lines[0]}" = "$(echo -e "123\tThe-Label\tssh-rsa bWFkZSB5b3UgbG9vaw==")" ]]
  [[ "${lines[1]}" = "$(echo -e "124\tThe-Label 2\tssh-rsa Zm9vbGVkIHlvdSB0d2ljZT8=")" ]]
}

@test "deploykey - delete" {
  shellmock_expect curl \
    --type partial \
    --match 'dummy-repo/deploy-keys' \
    --status 0 \
    --output ""

  run deploykey delete dummy-repo 8c08f70d-cf6e-44b0-8668-734209ab7a65

  [[ "$status" = "0" ]]
}

@test "webhook - unknown sub cmd" {
  run webhook foo-bar

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Unknown subcommand" ]]
}

@test "webhook - list-events" {
  run webhook list-events

  [[ "$status" = "0" ]]
  [[ "$output" =~ "repo:push" ]]
  [[ "$output" =~ "issue:updated" ]]
}

@test "webhook - list" {
  shellmock_expect curl \
    --type partial \
    --match 'dummy-repo/hooks' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/webhooks.json)"

  run webhook list dummy-repo

  [[ "$status" = "0" ]]
  [[ "${lines[0]}" = "$(echo -e "{00000000-0000-0000-0000-000000000000}\tJira")" ]]
  [[ "${lines[1]}" = "$(echo -e "{00000000-0000-0000-4444-000000000000}\tPull Request Commit Links")" ]]
  [[ "${lines[2]}" = "$(echo -e "{00000000-0000-0000-3333-000000000000}\tBitbucket code search")" ]]
  [[ "${lines[3]}" = "$(echo -e "{00000000-0000-0000-2222-000000000000}\tChat Notifications")" ]]
}

@test "webhook - add" {
  shellmock_expect curl \
    --type partial \
    --match 'dummy-repo/hooks' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/webhook-added.json)"

  local options
  declare -A options

  options["url"]="http://example.com"
  options["description"]="Test"
  events=("repo:push")

  run webhook add dummy-repo
  [[ "$status" = "0" ]]
}

@test "webhook - delete" {
  shellmock_expect curl \
    --type partial \
    --match 'dummy-repo/hooks' \
    --status 0 \
    --output ""

  run webhook delete dummy-repo 00000000-0000-0000-0000-000000000000
  [[ "$status" = "0" ]]
}

@test "project - unknown sub cmd" {
  run project foo-bar

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Unknown subcommand" ]]
}

@test "pullrequest - list" {
    shellmock_expect curl \
      --type partial \
      --match 'repositories/dummy/dummy-repo/pullrequests' \
      --status 0 \
      --output "$(< $BATS_TEST_DIRNAME/_data/responses/pullrequest-list.json)"

    run pullrequest list "dummy-repo"

  [[ "$status" = "0" ]]
  [[ "${lines[0]}" = "$(echo -e "420\tPullrequest title\tJohn Doe | SpaceShips")" ]]
}

@test "pullrequest - create" {
  run pullrequest create "dummy-repo"

  [[ "$status" = "1" ]]
  [[ "${lines[0]}" = "$(echo -e "\e[31mRequired argument 'source branch' is missing\e[0m")" ]]

  run pullrequest create "dummy-repo" "source-branch"
  [[ "$status" = "1" ]]
  [[ "${lines[0]}" = "$(echo -e "\e[31mRequired argument 'target branch' is missing\e[0m")" ]]

  shellmock_expect curl \
    --type partial \
    --match 'repositories/dummy/dummy-repo/pullrequests' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/pullrequest-created.json)"

  run pullrequest create "dummy-repo" "source-branch" "target-branch"
  [[ "$status" = "0" ]]
  [[ "${lines[0]}" = "Pull request created" ]]
  [[ "${lines[1]}" = "https://bitbucket.org/dummy/dummy-repo/pull-requests/42" ]]

}

@test "project - list" {
  shellmock_expect curl \
    --type partial \
    --match 'workspaces/dummy/projects' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/projects-get.json)"

  run project list

  [[ "$status" = "0" ]]
  [[ "${lines[0]}" = "$(echo -e "API\tAPI")" ]]
  [[ "${lines[1]}" = "$(echo -e "APPS\tApps")" ]]
  [[ "${lines[2]}" = "$(echo -e "DOC\tDocumentation")" ]]
  [[ "${lines[3]}" = "$(echo -e "IN\tInternal")" ]]
}

@test "project - add private" {
  shellmock_expect curl \
    --type partial \
    --match 'workspaces/dummy/projects' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/projects-created.json)"

  declare -A options
  options["key"]="FOO"
  run project add foo

  [[ "$status" = "0" ]]
  [[ "${lines[0]}" = "https://bitbucket.org/dummy/workspace/projects/FOO" ]]  # html link is output

  shellmock_verify
  echo "${capture[@]}"
  [[ "${capture[@]}" =~ "\"is_private\": true" ]]
}

@test "project - add public" {
  shellmock_expect curl \
    --type partial \
    --match 'workspaces/dummy/projects' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/projects-created.json)"

  declare -A options
  options["key"]="FOO"
  options["description"]="A random test description"
  options["public"]=1
  run project add foo

  [[ "$status" = "0" ]]
  [[ "${lines[0]}" = "https://bitbucket.org/dummy/workspace/projects/FOO" ]]  # html link is output

  shellmock_verify
  echo "${capture[@]}"
  [[ "${capture[@]}" =~ "\"is_private\": false" ]]
  [[ "${capture[@]}" =~ "\"key\": \"FOO\"" ]]
  [[ "${capture[@]}" =~ "\"name\": \"foo\"" ]]
  [[ "${capture[@]}" =~ "\"description\": \"A random test description\"" ]]
}

@test "project add - fail: already existing" {
  shellmock_expect curl \
    --type partial \
    --match 'workspaces/dummy/projects' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/projects-already-existing.json)"

  declare -A options
  options["key"]="FOO"
  run project add foo

  [[ "$status" = "1" ]]
  [[ "$output" =~ "already exists" ]]
}

@test "project delete - fail: not existing" {
  shellmock_expect curl \
    --type partial \
    --match 'workspaces/dummy/projects/FOO' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/projects-delete-fail.json)"

  run project delete FOO

  [[ "$status" = "1" ]]
  [[ "$output" =~ "No Project matches" ]]
}

@test "project delete" {
  shellmock_expect curl \
    --type partial \
    --match 'workspaces/dummy/projects/FOO' \
    --status 0 \
    --output ""

  run project delete FOO

  [[ "$status" = "0" ]]
}

@test "commit - missing commit id" {
  run commit baz repo

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Required argument 'commitId' missing" ]]
}

@test "commit - missing repo" {
  run commit baz

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Required argument 'repo' missing" ]]
}

@test "commit - missing sub command" {
  run commit

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Required argument 'sub command' missing" ]]
}

@test "commit - unknown sub cmd" {
  run commit baz repo id

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Unknown subcommand" ]]
}

@test "commit approve - success" {
  shellmock_expect curl \
    --type partial \
    --match 'repositories/dummy/test/commit/123456/approve' \
    --status 0 \
    --output ""

  run commit approve test 123456

  [[ "$status" = "0" ]]
  shellmock_verify
  [[ "${capture[0]}" == *"repositories/dummy/test/commit/123456/approve"* ]]
}

@test "commit approve - commit not found" {
  shellmock_expect curl \
    --type partial \
    --match 'repositories/dummy/test/commit/9782346876/approve' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/commit-not-found.json)"

  run commit approve test 9782346876

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Commit not found" ]]
}

@test "commit unapprove" {
  shellmock_expect curl \
    --type partial \
    --match 'repositories/dummy/repo/commit/54280dec/approve' \
    --status 0 \
    --output ""

  run commit unapprove repo 54280dec

  [[ "$status" = "0" ]]
  shellmock_verify
  [[ "${capture[0]}" == *"repositories/dummy/repo/commit/54280dec/approve"* ]]
  [[ "${capture[0]}" == *"-X DELETE"* ]]
}

@test "commit unapprove - commit not found" {
  shellmock_expect curl \
    --type partial \
    --match 'repositories/dummy/test/commit/9782346876/approve' \
    --status 0 \
    --output "$(< $BATS_TEST_DIRNAME/_data/responses/commit-not-found.json)"

  run commit unapprove test 9782346876

  [[ "$status" = "1" ]]
  [[ "$output" =~ "Commit not found" ]]
}
