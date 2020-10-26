#!/usr/bin/env bash
set -o pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="0.1.0"
readonly BASE_URL=https://api.bitbucket.org/2.0
readonly hookEvents=(
  "repo:push"
  "repo:fork"
  "repo:updated"
  "repo:commit_comment_created"
  "repo:commit_status_created"
  "repo:commit_status_updated"
  "pullrequest:created"
  "pullrequest:updated"
  "pullrequest:approved"
  "pullrequest:fulfilled"
  "pullrequest:unapproved"
  "pullrequest:rejected"
  "pullrequest:comment_created"
  "pullrequest:comment_deleted"
  "pullrequest:comment_updated"
  "issue:comment_created"
  "issue:created"
  "issue:updated"
)
readonly cacheDir="${XDG_CACHE_HOME:-"$HOME/.cache"}/bitbutler"

configfile="$HOME/.bitbucket.conf"
if [[ -n "$BB_CONFIG_FILE" ]]; then
  configfile="$BB_CONFIG_FILE"
fi

if [[ -r "$configfile" ]]; then
  # shellcheck source=/dev/null
  . "$configfile"
fi

# allow BB_VENDOR_PATH to be set from outside
if [[ -z "$BB_VENDOR_PATH" ]]; then
  BB_VENDOR_PATH="$(pwd)"
fi

if [[ ! -d "$BB_VENDOR_PATH" ]]; then
  echo "Could not find dependencies"
  exit 1
fi

[[ -r "$BB_VENDOR_PATH/utils.sh" ]] || {
  echo "Cannot open utils.sh"
  exit 1
}
# shellcheck source=src/utils.sh
. "$BB_VENDOR_PATH/utils.sh"

function version() {
  echo "$SCRIPT_VERSION"
  exit 0
}

function usage() {
  local b c w y

  y="$(echo -e "\\e[33m")"
  b="$(echo -e "\\e[34m")"
  c="$(echo -e "\\e[36m")"
  w="$(echo -e "\\e[m")"

  cat <<EOF
bitbutler <${c}command${w}> [${c}options${w}]

    Bitbucket management and helper tool

${b}Commands$w

    ${b}help$w
        Display this help screen

    ${b}authtest$w
        Test the supplied credentials

    ${b}branches ${c}REPO$w
        List branches of repository ${c}REPO$w

    ${b}config$w
        Initialize an empty config file to fill

    ${b}deploykey$w ${c}SUBCOMMAND$w ${c}REPO$w [${c}LABEL KEY$w] [${c}KEY ID$w]
        Work with deploy keys

        ${y}add$w       Add a new deploy key to given repo
        ${y}delete$w    Delete a deploy key by id
        ${y}list$w      List deploy keys

    ${b}open$w [${c}WORD$w]
        Open bitbucket in the default browser.

        ${y}apidoc$w      Open API reference
        ${y}dashboard$w   Open the dashboard (default)

    ${b}project$w ${c}SUBCOMMAND$w [${c}KEY$w]
        Work with projects

        ${y}add$w       Create a new project
        ${y}delete$w    Delete a project by KEY
        ${y}list$w      List projects

    ${b}pullrequest ${c}SUBCOMMAND$w ${c}REPO$w
        Work with pull requests

        ${y}list$w      List pull requests

    ${b}repo$w ${c}SUBCOMMAND$w
        Work with repositories

        ${y}add$w       Create a new repository
        ${y}delete$w    Delete a repository
        ${y}list$w      List repository

    ${b}restriction$w ${c}SUBCOMMAND$w ${c}REPO$w
        Work with branch restrictions

        ${y}add$w       Add a new restriction
        ${y}delete$w    Delete a branch restriction by id
        ${y}list$w      List branch restrictions

    ${b}reviewer$w ${c}SUBCOMMAND$w ${c}REPO$w [${c}USERNAME$w]
        Work with default reviewers

        ${y}add$w       Add a new user to the default reviewers
        ${y}delete$w    Delete a default reviewer
        ${y}list$w      List default reviewers

    ${b}team$w ${c}SUBCOMMAND$w ${c}team$w
        Work with teams

        ${y}members$w   List team members

    ${b}version$w
        Show the script version

    ${b}webhook$w ${c}SUBCOMMAND$w ${c}REPO$w
        Work with repository webhooks

        ${y}add$w         Add a new hook
        ${y}delete$w      Delete a hook
        ${y}list$w        List webhooks
        ${y}list-events$w List valid webhook events

${b}Options$w

    $b-u, --user ${c}WORD$w
        Bitbucket username

    $b-p, --pass ${c}WORD$w
        Bitbucket password

    $b-o, --owner ${c}WORD$w
        Bitbucket repository owner

    $b-v, --verbose$w
        Verbose output

    $b-D, --debug$w
        Output internal debugging information

    $b-q, --quiet$w
        Less output
EOF

  exit 0
}

function requirements() {
  v 'Checking script requirements...'

  (jq --version &>/dev/null) || die 'jq not found'

  if [[ ! "$cmd" =~ config|help|version ]]; then
    [[ -n "$bitbucket_owner" ]] || die 'owner not set'
    [[ -n "$bitbucket_user" ]] || die 'user not set'
    [[ -n "$bitbucket_pass" ]] || die 'password not set'
  fi
}

function parseArgs() {
  remainingArgs=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      -u | --user)
        bitbucket_user="$2"
        shift
        ;;
      -p | --pass)
        bitbucket_pass="$2"
        shift
        ;;
      -o | --owner)
        bitbucket_owner="$2"
        shift
        ;;
      -v | --verbose)
        # shellcheck disable=SC2034
        verbose=1
        ;;
      -D | --debug)
        # shellcheck disable=SC2034
        debug=1
        ;;
      -q | --quiet)
        # shellcheck disable=SC2034
        quiet=1
        ;;
      -h | --help)
        usage
        ;;
      -V | --version)
        version
        ;;
      -d | --description)
        options["description"]="$2"
        shift
        ;;
      -U | --url)
        options["url"]="$2"
        shift
        ;;
      -e | --events)
        IFS=', ' read -r -a events <<<"$2"
        shift
        ;;
      -k | --key)
        options["key"]="$2"
        shift
        ;;
      -P | --public)
        options["public"]=1
        ;;
      *)
        if beginsWith "$1" "-"; then
          die "Unknown option '$1'"
        fi

        if [[ -z "$cmd" ]]; then
          cmd="$1"
        else
          remainingArgs+=("$1")
        fi
        ;;
    esac
    shift
  done

  if [[ ${#events[@]} -eq 0 ]]; then
    events=("${hookEvents[@]}")
  fi
}

function _request() {
  local url method body response

  method="$1"
  url="$2"
  body="${3:-""}"

  dbg "Request: $method\n $2\n $body"

  response="$(curl -s -X "$method" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -u "$bitbucket_user:$bitbucket_pass" \
    "$BASE_URL$url" -d "$body")"

  dbg "Response: $response"
  echo "$response"
}

# Fetch all pages for a GET request, combining the results
# NOTE: When narrowing returned data with `fields` it needs to include `next`
# params: The URL to GET
# returns: an array of combined responses `values` arrays
function fetchAllPages() {
  local url combined current next nextUrl currentValues

  url="$1"

  current="$(_request GET "$@")"
  combined="$(jq '.values' <<<"$current")"

  while next="$(jq -re '.next' <<<"$current")"; do
    nextUrl="${next#$BASE_URL}"
    dbg "nextUrl '$nextUrl'"
    current="$(_request GET "$nextUrl")"
    dbg "Response: $current"
    currentValues="$(jq '.values' <<<"$current")"
    combined="$(echo -e "$combined\n$currentValues" | jq '.[]' | jq -s)"
  done

  echo "$combined"
}

# Check for an error in the bitbucket response
# When an error is found, print it formatted and exit the script
function checkError() {
  local response message

  response="$1"
  if ! type="$(echo -E "$response" | jq -jr '.type // ""' 2>/dev/null)"; then
    die "$response"
  fi

  if [[ -n "$type" ]] && [[ "$type" == "error" ]]; then
    message="$(echo -E "$response" | jq -r '.error | @text "\(.message // "")\n\(.detail // "")\n\((.fields // "") | tostring)\n"')"
    if [[ -z "$message" ]]; then
      die "Unknown api error: $response"
    fi
    die "$message"
  fi
}

# Get user info required to work with them
# Parameters:
#   search    The value to search for - can be nickname, accountId etc, depending on type
#   type      The type of search to do valid values: nickname|uuid|account_id
# Return: JSON blob with nick, uuid and account_id
function lookupUser() {
  local search type userInfo
  local -r endpoint="/teams/${bitbucket_owner}/members"
  local -r cacheFile="$cacheDir/users.json"

  search="$1"
  type="${2:-"nickname"}"

  if ! jq -re ".[] | select(.$type | contains(\"$search\"))" "$cacheFile" >/dev/null; then
    dbg "lookupUser: user not in cache, refreshing"
    fetchAllPages "$endpoint" >"$cacheFile"
  fi

  userInfo="$(jq "map(select(.$type | contains(\"$search\")))" "$cacheFile")"

  dbg "lookupUser: userInfo: '$userInfo'"
  echo "$userInfo"
}

function checkExactlyOneMatch() {
  if [[ "$1" -gt "1" ]]; then
    die "Matched more than 1 user"
  elif [[ "$1" -eq "0" ]]; then
    die "Found no matching user"
  fi
}

function getUserAttributeFromName() {
  local userBlob numUsers

  userBlob="$(lookupUser "$1" nickname)"
  numUsers="$(jq 'length' <<<"$userBlob")"
  checkExactlyOneMatch "$numUsers"

  jq -r ".[0].$2" <<<"$userBlob"
}

#
# Commands
#

function authtest() {
  local response username

  response="$(_request GET '/user')"
  username=$(echo -n "$response" | jq -r '.username')
  if [[ -n "$username" ]]; then
    l "\\e[32mlogged in as $(echo -n "$response" | jq '.username')\\e[m"
  else
    e "authentication failed"
  fi
}

function branches() {
  local repo

  repo="$1"
  if [[ -z "$repo" ]]; then
    die "Required argument REPO missing"
  fi

  response=$(_request GET "/repositories/${bitbucket_owner}/$repo/refs?pagelen=100&fields=values.type,values.name")
  checkError "$response"
  echo -n "$response" | jq -r '.values[] | select(.type = "branch") | .name'
}

function config() {
  l 'Creating a config file skeleton for you...'

  if [[ -r "$configfile" ]]; then
    l "Config file $configfile already exists, bailing out"
    exit 0
  fi

  cat <<BASH >"$configfile"
# bitbutler configuration file
#
# This is sourced by bash, so no spaces around assignment operators, and
# whitespace in values need to be quoted.

# Bitbucket user name for authentication
bitbucket_user=

# Bitbucket password for authentication
bitbucket_pass=

# Bitbucket default owner
bitbucket_owner=

BASH

  l "Created config file $configfile - please edit"
}

function deploykey() {
  local repo subCmd label key response

  subCmd="$1"
  repo="$2"
  label="$3"
  key="$4"
  [[ -n "$subCmd" ]] || die "Required argument 'sub command' missing"
  [[ -n "$repo" ]] || die "Required argument 'repo' missing"

  local -r endpoint="/repositories/${bitbucket_owner}/$repo/deploy-keys"

  case "$subCmd" in
    list)
      response=$(_request GET "$endpoint")
      checkError "$response"

      echo -n "$response" | jq -r '.values[] | [.id, .label] | @tsv'
      ;;
    add)
      [[ -n "$label" ]] || die "Required argument 'label' missing"
      [[ -n "$key" ]] || die "Required argument 'key' missing"

      v "Adding key with label '$label' and key '$key'"

      response="$(_request POST "$endpoint" "{\"key\": \"$key\", \"label\": \"$label\"}")"
      checkError "$response"
      ;;
    delete)
      [[ -n "$label" ]] || die "Required argument 'id' missing"
      # label is misused as id here
      response="$(_request DELETE "$endpoint/$label")"
      checkError "$response"
      ;;
    *)
      die "Unknown subcommand given: '$subCmd'"
      ;;
  esac
}

function open() {
  local what

  what=${1:-dashboard}

  case "$what" in
    apidoc)
      xdg-open "https://developer.atlassian.com/bitbucket/api/2/reference/resource/"
      ;;
    dashboard)
      xdg-open "https://bitbucket.org/dashboard/overview"
      ;;
    *)
      die "Unknown page given: '$what'"
      ;;
  esac
}

function project() {
  local subCmd response name key description isPrivate requestJson

  subCmd="$1"
  name="$2"
  [[ -n "$subCmd" ]] || die "Required argument 'sub command' missing"

  local -r endpoint="/workspaces/${bitbucket_owner}/projects"

  case "$subCmd" in
    list)
      response="$(fetchAllPages "$endpoint?fields=next,values.key,values.name&sort=name")"
      jq -r '.[] | [.key, .name] | @tsv' <<<"$response"
      ;;
    add)
      [[ -n "$name" ]] || die "Required argument 'name' missing"
      [[ -n "${options[key]}" ]] || die "Required argument 'key' missing"

      description="${options[description]:-""}"
      isPrivate="true"
      if [[ -n "${options["public"]}" ]]; then
        isPrivate="false"
      fi

      requestJson="$(
        cat <<JSON
{
  "name": "$name",
  "key": "${options[key]}",
  "description": "$description",
  "is_private": $isPrivate
}
JSON
      )"

      dbg "Adding project with config $requestJson"

      response="$(_request POST "$endpoint" "$requestJson")"
      checkError "$response"
      jq -r ".links.html.href" <<<"$response"
      ;;
    delete)
      key="$2"
      [[ -n "$key" ]] || die "Required argument 'key' missing"

      response="$(_request DELETE "$endpoint/$key")"
      checkError "$response"
      ;;
    *)
      die "Unknown subcommand given: '$subCmd'"
      ;;
  esac
}

function pullrequest() {
  local repo subCmd response

  subCmd="$1"
  repo="$2"

  [[ -n "$subCmd" ]] || die "Required argument 'sub command' missing"
  [[ -n "$repo" ]] || die "Required argument 'repo' missing"

  local -r endpoint="/repositories/${bitbucket_owner}/${repo}/pullrequests"

  case "$subCmd" in
    list)
      response=$(_request GET "$endpoint") # if you need pagination here, you lost control of your life, sorry.
      checkError "$response"
      jq -r '.values[] | [ .id, .title, .author.display_name ] | @tsv' <<<"$response"
      ;;
  esac
}

function repo() {
  local repo subCmd response

  subCmd="$1"
  repo="$2"
  [[ -n "$subCmd" ]] || die "Required argument 'sub command' missing"

  local -r endpoint="/repositories/${bitbucket_owner}/"

  case "$subCmd" in
    delete)
      [[ -n "$repo" ]] || die "Required argument 'repo' missing"
      # option --force => non-interactive

      # this is an optional parameter, not what shellcheck thinks
      # shellcheck disable=SC2119
      confirm
      response="$(_request DELETE "$endpoint$repo")"
      checkError "$response"
      ;;
    list)
      fetchAllPages "$endpoint?pagelen=100&fields=next,values.full_name&sort=full_name" |
        jq -r ".[].full_name | sub(\"$bitbucket_owner/\"; \"\")"
      ;;
    *)
      die "Unknown subcommand given: '$subCmd'"
      ;;
  esac
}

function restriction() {
  local repo subCmd

  subCmd="$1"
  repo="$2"
  if [[ -z "$subCmd" ]] || [[ -z "$repo" ]]; then
    die "Required argument missing"
  fi

  case "$subCmd" in
    list)
      response=$(_request GET "/repositories/${bitbucket_owner}/$repo/branch-restrictions?pagelen=100")
      checkError "$response"
      echo -n "$response" | jq -r '.values[] | [.pattern, .kind, .value]'
      ;;
    *)
      die "Unknown subcommand given: '$subCmd'"
      ;;
  esac
}

function reviewer() {
  local repo subCmd username response accountId

  subCmd="$1"
  repo="$2"
  username="$3"
  [[ -n "$subCmd" ]] || die "Required argument 'sub command' missing"
  [[ -n "$repo" ]] || die "Required argument 'repo' missing"

  local -r endpoint="/repositories/${bitbucket_owner}/$repo/default-reviewers"

  case "$subCmd" in
    list)
      response=$(_request GET "$endpoint")
      checkError "$response"
      echo -n "$response" | jq -r '.values[] | [.nickname] | @tsv'
      ;;
    add)
      [[ -n "$username" ]] || die "Required argument 'username' missing"

      accountId="$(getUserAttributeFromName "$username" account_id)"

      # the body of this request is undocumented by atlassian
      # doing it as mentioned in the docs results in a `400 Bad Request`
      response="$(_request PUT "$endpoint/$accountId" "{\"mention_id\":\"$accountId\"}")"
      checkError "$response"
      ;;
    delete)
      [[ -n "$username" ]] || die "Required argument 'username' missing"

      accountId="$(getUserAttributeFromName "$username" account_id)"
      response="$(_request DELETE "$endpoint/$accountId")"
      checkError "$response"
      ;;
    *)
      die "Unknown subcommand given: '$subCmd'"
      ;;
  esac
}

function team() {
  local team subCmd response

  subCmd="$1"
  team="$2"
  [[ -n "$subCmd" ]] || die "Required argument 'sub command' missing"
  [[ -n "$team" ]] || die "Required argument 'team' missing"

  local -r endpoint="/teams/${bitbucket_owner}"

  case "$subCmd" in
    members)
      response=$(_request GET "$endpoint/members")
      checkError "$response"
      echo -n "$response" | jq -r '.values[] | [.nickname] | @tsv'
      ;;
    *)
      die "Unknown subcommand given: '$subCmd'"
      ;;
  esac
}

function webhook() {
  local repo subCmd uuid response

  subCmd="$1"
  repo="$2"
  uuid="$3"
  [[ -n "$subCmd" ]] || die "Required argument 'sub command' missing"

  local -r endpoint="/repositories/${bitbucket_owner}/$repo/hooks"

  case "$subCmd" in
    list)
      [[ -n "$repo" ]] || die "Required argument 'repo' missing"

      response=$(_request GET "$endpoint?fields=values.uuid,values.description")
      checkError "$response"
      echo -n "$response" | jq -r '.values[] | [.uuid, .description] | @tsv'
      ;;
    add)
      [[ -n "$repo" ]] || die "Required argument 'repo' missing"
      [[ "${#events[@]}" -ne 0 ]] || die "Required argument 'events' missing"
      [[ -n "${options[url]}" ]] || die "Required argument 'url' missing"
      [[ -n "${options[description]}" ]] || die "Required argument 'description' missing"

      eventsJson="$(printf ',"%s"' "${events[@]}")"
      requestJson="$(
        cat <<JSON
{
  "description": "${options[description]}",
  "url": "${options[url]}",
  "active": true,
  "events": [
    ${eventsJson:1}
  ]
}
JSON
      )"

      dbg "Adding webhook with config $requestJson"

      response="$(_request POST "$endpoint" "$requestJson")"
      checkError "$response"
      ;;
    delete)
      [[ -n "$repo" ]] || die "Required argument 'repo' missing"
      [[ -n "$uuid" ]] || die "Required argument 'uuid' missing"

      response="$(_request DELETE "$endpoint/$uuid")"
      checkError "$response"
      ;;
    list-events)
      printf '%s\n' "${hookEvents[@]}"
      ;;
    *)
      die "Unknown subcommand given: '$subCmd'"
      ;;
  esac
}

function main() {
  local cmd remainingArgs options
  declare -A options

  parseArgs "$@"
  requirements

  mkdir -p "$cacheDir"

  dbg "Executing command '$cmd'"
  case "$cmd" in
    authtest | config | open | branches)
      $cmd "$remainingArgs"
      ;;
    restriction | reviewer | deploykey | repo | webhook | team | project | pullrequest)
      # shellcheck disable=SC2086
      $cmd ${remainingArgs[*]}
      ;;
    help | "")
      usage
      ;;
    version)
      version
      ;;
    *)
      die "Unknown command given: '$cmd'\nSee 'help' for usage information"
      ;;
  esac

  exit 0
}

if [[ "$0" != *bats* ]]; then
  main "$@"
fi
