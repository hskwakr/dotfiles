#!/bin/bash
# PreToolUse hook: ask before any outbound command aimed anywhere but
# hskwakr/task-notes.
#
#   (no output), exit 0   nothing outbound, or the target is task-notes
#   ask JSON,     exit 0   the target is another repository, or is not knowable
#
# stdout carries the decision and nothing else. One stray line turns the whole
# decision into plain text and the tool call proceeds -- so every diagnostic
# goes to stderr. `exit 1` does not block either, which is why unexpected
# failures here end in `ask` rather than in an error.
#
#   outbound-guard.sh              read a hook event on stdin, decide
#   outbound-guard.sh --explain    same, but print the reasoning for a human
#   outbound-guard.sh --check      report whether the guard is alive and correct
#
# Specification: task-notes projects/task-notes/workflow/GH-63-outbound-push-guard/spec.md

readonly ALLOWED_HOST="github.com"
readonly ALLOWED_REPO="hskwakr/task-notes"
readonly REASON_MAX=400
# The parser lives beside this script; both are symlinked into ~/.claude/hooks.
# If it goes missing, awk fails and every outbound command ends in ask.
ANALYZER="$(dirname "$0")/outbound-guard.awk"

VERDICT=""
REASON=""

# --------------------------------------------------------------- primitives

# Reads all of stdin without spawning anything. Every Bash tool call pays this.
read_stdin() {
    STDIN_RAW=""
    IFS= read -r -d '' STDIN_RAW
    return 0
}

# Cheap superset of the real matcher. Anything outbound contains one of these,
# so a miss here is a miss everywhere -- keep it loose.
looks_outbound() {
    case $1 in
        *git*push*|*push*git*) return 0 ;;
        *"gh "*|*"gh	"*)     return 0 ;;
        *"npm publish"*)        return 0 ;;
    esac
    return 1
}

json_escape() {
    local s=$1
    case $s in
        *[$'\001'-$'\037']*) printf 'the reason contained control characters'; return 0 ;;
    esac
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf '%s' "$s"
}

emit_ask() {
    local reason=$1 cut
    # Under a C locale bash slices by byte, so a blind cut can split a UTF-8
    # character. Invalid bytes make the JSON unparseable, and an unparseable
    # decision is silently dropped -- back off to the last space instead.
    if [ ${#reason} -gt $REASON_MAX ]; then
        cut=${reason:0:$REASON_MAX}
        case $cut in
            *\ *) reason="${cut% *}..." ;;
            *)    reason="the guard is asking about a command it could not attribute to hskwakr/task-notes" ;;
        esac
    fi
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' \
        "$(json_escape "$reason")"
}

# owner/repo out of a remote URL. Filesystem paths are deliberately rejected:
# a local remote is not task-notes, so it has to reach the ask branch.
normalize_repo() {
    local u=$1 rest host owner name
    NR_HOST=""; NR_NWO=""
    [ -n "$u" ] || return 1
    case $u in /*|.*|~*) return 1 ;; esac
    u=${u%/}; u=${u%.git}
    case $u in
        *://*)  rest=${u#*://}; rest=${rest#*@}
                host=${rest%%/*}; host=${host%%:*}
                rest=${rest#*/} ;;
        *@*:*)  rest=${u#*@}
                host=${rest%%:*}
                rest=${rest#*:}; rest=${rest#/} ;;
        */*/*)  host=${u%%/*}; rest=${u#*/} ;;
        */*)    host=$ALLOWED_HOST; rest=$u ;;
        *)      return 1 ;;
    esac
    case $rest in */*) ;; *) return 1 ;; esac
    owner=${rest%%/*}; name=${rest#*/}; name=${name%%/*}
    [ -n "$owner" ] && [ -n "$name" ] || return 1
    NR_HOST=$host
    NR_NWO="$owner/$name"
    return 0
}

is_allowed_repo() {
    local host=$1 nwo=$2 ok=1
    shopt -s nocasematch
    [[ $host == "$ALLOWED_HOST" && $nwo == "$ALLOWED_REPO" ]] && ok=0
    shopt -u nocasematch
    return $ok
}

# ------------------------------------------------------------ path -> repo
# Sets PR_NWO to the repository a directory pushes to, and PR_ALL to every
# distinct repository its remotes name. Passing requires all of them to be
# task-notes: one stray remote is enough to want a human.

# Pulls one remote out of the record string path_repo builds. bash 3.2 has no
# associative arrays, and a remote name is not restricted to what a shell
# variable name may hold -- "my-fork" and "my.dots" are both valid. git does
# reject tabs and newlines in one, so a record string can hold any of them.
rmap_get() { # rmap_get <records> <name> -> RM_URL
    local rest=${1#*$'\n'"$2"$'\t'}
    RM_URL=""
    [ "$rest" != "$1" ] || return 1
    RM_URL=${rest%%$'\n'*}
    return 0
}

path_repo() {
    local dir=$1 want=$2
    local out cfg line name rest kind url ghres="" pushrec="" subrec=""
    local primary="" all=" " resolved="" rmap=$'\n'
    PR_HOST=""; PR_NWO=""; PR_ALL=""; PR_ERR=""

    # `git remote -v` is git's own answer, so remote.<n>.pushurl,
    # url.<base>.pushInsteadOf, insteadOf and --worktree config are already
    # applied. Reading remote.<n>.url instead meant reimplementing that
    # precedence. It exits 128 outside a repository and when the directory is
    # gone.
    out=$(git -C "$dir" remote -v 2>/dev/null) ||
        { PR_ERR="not inside a git working tree: $dir"; return 1; }

    while IFS=$'\t' read -r name rest; do
        [ -n "$name" ] && [ -n "$rest" ] || continue
        kind=${rest##* }          # (fetch) or (push)
        url=${rest% *}
        if normalize_repo "$url"; then url="$NR_HOST/$NR_NWO"; else url="?/$url"; fi
        case $all in *" $url "*) ;; *) all="$all$url " ;; esac
        # `git push <name>` follows the push URL, so that is what the map
        # answers with. Taking the first of several does not lose the rest:
        # they are in `all`, and one stray entry there already forces the ask.
        [ "$kind" = "(push)" ] || continue
        case $url in "?/"*) continue ;; esac
        case $rmap in *$'\n'"$name"$'\t'*) ;; *) rmap="$rmap$name"$'\t'"$url"$'\n' ;; esac
    done <<EOF
$out
EOF

    # `gh` picks its base repository from remote.<n>.gh-resolved before it looks
    # at any remote. The value is either "base" -- this remote is it -- or an
    # owner/repo that need not have a remote at all (cli/cli
    # pkg/cmd/factory/default.go).
    cfg=$(git -C "$dir" config --get-regexp \
        '^(remote\..*\.gh-resolved|push\.recursesubmodules|submodule\.recurse)$' 2>/dev/null)
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        name=${line%% *}
        case $name in
            push.recursesubmodules) pushrec=${line#* }; continue ;;
            submodule.recurse)
                # A key written with no value is true. `${line#* }` gives back
                # the whole line when there is no space to strip.
                subrec=${line#* }
                [ "$subrec" != "$line" ] || subrec=true
                continue ;;
        esac
        name=${name#remote.}; name=${name%.gh-resolved}
        url=${line#* }
        if [ "$url" = "base" ]; then resolved=$name; continue; fi
        case $url in */*) ;; *) continue ;; esac
        # An owner/repo carries no host of its own; it belongs to the host of
        # the remote that named it.
        if rmap_get "$rmap" "$name"; then ghres="${RM_URL%%/*}/$url"; else ghres="$ALLOWED_HOST/$url"; fi
        case $all in *" $ghres "*) ;; *) all="$all$ghres " ;; esac
    done <<EOF
$cfg
EOF

    [ "$rmap" != $'\n' ] || [ -n "$ghres" ] ||
        { PR_ERR="no GitHub remote is configured in $dir"; return 1; }

    # With submodules present, these make a plain `git push` send each changed
    # one to a remote of its own, which is not among the remotes read above.
    # push.recurseSubmodules wins when both are set (git-config(1)).
    if [ -e "$dir/.gitmodules" ]; then
        rest=$pushrec
        if [ -z "$rest" ]; then
            case $subrec in true|yes|on|1) rest=on-demand ;; esac
        fi
        case $rest in
            on-demand|only)
                PR_ERR="$dir pushes its submodules too, and their remotes are not the ones configured here"
                return 1 ;;
        esac
    fi

    if [ "$want" != "-" ]; then
        rmap_get "$rmap" "$want" ||
            { PR_ERR="remote \"$want\" of $dir is missing or is not a GitHub repository"; return 1; }
        primary=$RM_URL
    elif [ -n "$ghres" ]; then
        primary=$ghres
    else
        for name in $resolved upstream github origin; do
            [ -n "$name" ] || continue
            rmap_get "$rmap" "$name" && { primary=$RM_URL; break; }
        done
        if [ -z "$primary" ]; then
            rest=${rmap#$'\n'}; rest=${rest%%$'\n'*}
            primary=${rest#*$'\t'}
            [ "$primary" != "$rest" ] || primary=""
        fi
        [ -n "$primary" ] || { PR_ERR="no remote of $dir is a GitHub repository"; return 1; }
    fi

    PR_HOST=${primary%%/*}
    PR_NWO=${primary#*/}
    PR_ALL=$all
    return 0
}

# ----------------------------------------------------------------- decide
# Turns one command into VERDICT (pass|ask) and REASON. Anything it cannot
# account for ends as ask.
classify() {
    local cmd=$1 cwd=$2 depth=${3:-0}
    local facts line kind a b c nested_verdict nested_reason
    local -a rows

    VERDICT=""; REASON=""
    facts=$(printf '%s' "$cmd" | GUARD_CWD="$cwd" awk -f "$ANALYZER" 2>/dev/null) || {
        VERDICT="ask"; REASON="the guard could not analyse the command"; return 0; }

    # An analyser that is empty or truncated mid-file still exits 0 with no
    # output. Without the closing marker that is indistinguishable from a clean
    # "nothing outbound", so the absence of the marker has to block.
    case $facts in
        "END")     facts="" ;;
        *$'\n'END) facts=${facts%$'\n'END} ;;
        *) VERDICT="ask"; REASON="the guard's analyser did not run to completion"; return 0 ;;
    esac
    if [ -z "$facts" ]; then VERDICT="pass"; return 0; fi

    rows=()
    while IFS= read -r line; do
        [ -n "$line" ] && rows[${#rows[@]}]=$line
    done <<EOF
$facts
EOF

    for line in "${rows[@]}"; do
        IFS=$'\t' read -r kind a b c <<EOF
$line
EOF
        case $kind in
            NEST)
                if [ "$depth" -ge 2 ]; then
                    VERDICT="ask"; REASON="$b: nested too deeply for the guard to follow"; return 0
                fi
                classify "$a" "$cwd" $((depth + 1))
                nested_verdict=$VERDICT; nested_reason=$REASON
                VERDICT=""; REASON=""
                if [ "$nested_verdict" = "ask" ]; then
                    VERDICT="ask"; REASON="$b: $nested_reason"; return 0
                fi ;;
            ASK)
                VERDICT="ask"; REASON="$a"; return 0 ;;
            REPO)
                if ! is_allowed_repo "$a" "$b"; then
                    VERDICT="ask"; REASON="$c targets $a/$b"; return 0
                fi ;;
            PATH)
                if ! path_repo "$a" "$b"; then
                    VERDICT="ask"; REASON="$c: $PR_ERR"; return 0
                fi
                if ! is_allowed_repo "$PR_HOST" "$PR_NWO"; then
                    VERDICT="ask"; REASON="$c in $a targets $PR_HOST/$PR_NWO"; return 0
                fi
                case $PR_ALL in
                    " $ALLOWED_HOST/$ALLOWED_REPO "|" ") ;;
                    *) VERDICT="ask"
                       REASON="$c in $a: the repository also has remotes pointing at$PR_ALL"
                       return 0 ;;
                esac ;;
            *)
                VERDICT="ask"; REASON="the guard produced an unreadable result"; return 0 ;;
        esac
    done

    [ -n "$VERDICT" ] || VERDICT="pass"
    return 0
}

# ------------------------------------------------------------------ modes

run_hook() {
    read_stdin
    looks_outbound "$STDIN_RAW" || exit 0

    if ! command -v jq >/dev/null 2>&1; then
        # Without jq the hook input cannot be parsed. Match the raw text instead
        # of parsing it: heredoc bodies raise false positives, but the cost of
        # one is a dialog, and the cost of a miss is the whole point of the hook.
        emit_ask "jq is not installed, so the guard matched the raw hook input and could not identify the target repository"
        exit 0
    fi

    local parsed cmd cwd
    parsed=$(printf '%s' "$STDIN_RAW" | jq -r '(.cwd // ""), (.tool_input.command // "")' 2>/dev/null) || parsed=""
    case $parsed in
        *$'\n'*) cwd=${parsed%%$'\n'*}; cmd=${parsed#*$'\n'} ;;
        *) emit_ask "the guard could not read the hook input" ; exit 0 ;;
    esac

    [ -n "$cmd" ] || exit 0
    classify "$cmd" "$cwd"
    if [ "$VERDICT" = "pass" ]; then exit 0; fi
    emit_ask "${REASON:-the guard could not determine the target repository}"
    exit 0
}

run_explain() {
    read_stdin
    local cmd cwd parsed
    if command -v jq >/dev/null 2>&1; then
        parsed=$(printf '%s' "$STDIN_RAW" | jq -r '(.cwd // ""), (.tool_input.command // "")' 2>/dev/null)
        cwd=${parsed%%$'\n'*}; cmd=${parsed#*$'\n'}
    else
        echo "jq is not installed; the hook would ask for anything outbound." >&2
        cmd=$STDIN_RAW; cwd=$PWD
    fi
    [ -n "$cwd" ] || cwd=$PWD
    printf 'command : %s\ncwd     : %s\n' "$cmd" "$cwd"
    printf 'coarse  : %s\n' "$(looks_outbound "$cmd" && echo "outbound-looking" || echo "not outbound")"
    printf 'facts   :\n'
    printf '%s' "$cmd" | GUARD_CWD="$cwd" awk -f "$ANALYZER" | grep -v '^END$' | sed 's/^/          /'
    classify "$cmd" "$cwd"
    printf 'verdict : %s\n' "$VERDICT"
    [ "$VERDICT" = "ask" ] && printf 'reason  : %s\n' "$REASON"
    return 0
}

# --check answers the one question the hook cannot answer about itself: is it
# still wired in and still deciding correctly? Failure modes 5-a, 5-d and the
# missing-jq path are all silent in normal operation.
run_check() {
    local self settings rc=0 pass=0 fail=0

    self=$0
    printf 'outbound-guard self-check\n'
    printf '  script      : %s\n' "$self"
    if [ -x "$self" ]; then printf '  executable  : yes\n'
    else printf '  executable  : NO -- the hook cannot run\n'; rc=1; fi
    if [ -r "$ANALYZER" ]; then printf '  parser      : %s\n' "$ANALYZER"
    else printf '  parser      : MISSING (%s) -- every outbound command will ask\n' "$ANALYZER"; rc=1; fi

    if command -v jq >/dev/null 2>&1; then
        printf '  jq          : %s\n' "$(command -v jq)"
    else
        printf '  jq          : missing -- every outbound command will ask\n'
    fi

    settings="$HOME/.claude/settings.json"
    if [ ! -f "$settings" ]; then
        printf '  registered  : NO -- %s does not exist\n' "$settings"; rc=1
    elif ! grep -q 'outbound-guard.sh' "$settings"; then
        printf '  registered  : NO -- %s does not mention outbound-guard.sh\n' "$settings"; rc=1
    else
        printf '  registered  : yes (%s)\n' "$settings"
        if command -v jq >/dev/null 2>&1; then
            local entry
            entry=$(jq -c '.hooks.PreToolUse[]? | select(any(.hooks[]?; .command // "" | test("outbound-guard")))' "$settings" 2>/dev/null)
            if [ -z "$entry" ]; then
                printf '  hook entry  : NO -- it is not under hooks.PreToolUse\n'; rc=1
            else
                printf '  matcher     : %s\n' "$(printf '%s' "$entry" | jq -r '.matcher // "(none)"')"
                if printf '%s' "$entry" | jq -e 'any(.hooks[]?; .async == true)' >/dev/null 2>&1; then
                    printf '  async       : TRUE -- the decision never reaches Claude Code\n'; rc=1
                else
                    printf '  async       : absent (correct)\n'
                fi
                printf '  timeout     : %s\n' "$(printf '%s' "$entry" | jq -r '[.hooks[]?.timeout] | map(select(. != null)) | first // "unset (defaults to 600s)"')"
            fi
        fi
    fi

    # Decisions that need no repository on disk, so this runs anywhere.
    check_case() {
        local want=$1 cmd=$2
        classify "$cmd" "$HOME"
        if [ "$VERDICT" = "$want" ]; then pass=$((pass + 1))
        else fail=$((fail + 1)); printf '  FAIL want=%s got=%s : %s\n' "$want" "$VERDICT" "$cmd"; fi
    }
    check_case ask  'gh pr edit -R evetech-jp/oripa-backend-infra 2028 --base dev'
    check_case ask  'git push git@github.com:evetech-jp/oripa-backend-infra.git main'
    check_case ask  'gh api -X PATCH repos/o/r/pulls/1'
    check_case ask  'GH_REPO=o/r gh pr close 1'
    check_case ask  'npm publish'
    check_case ask  'cd $UNSET_DIR && git push'
    check_case ask  'bash -c "cd /org && git push"'
    check_case pass 'gh pr edit -R hskwakr/task-notes 1 --title x'
    check_case pass 'gh api -X GET search/code -f q=foo'
    check_case pass 'gh pr view 12'
    check_case pass 'git fetch origin'
    check_case pass 'echo hello'
    printf '  decisions   : %d passed, %d failed\n' "$pass" "$fail"
    [ "$fail" -eq 0 ] || rc=1

    if [ "$rc" -eq 0 ]; then printf '  result      : the guard is alive and deciding correctly\n'
    else printf '  result      : SOMETHING IS WRONG -- see the lines above\n'; fi
    return $rc
}


case ${1:-} in
    --check)   run_check ;;
    --explain) run_explain ;;
    *)         run_hook ;;
esac
