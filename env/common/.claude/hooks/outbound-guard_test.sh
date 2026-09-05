#!/bin/bash
# Decision tests for outbound-guard.sh. Builds two throwaway repositories with
# fake remotes, so it needs no network and no particular checkout on the machine.
#
#   ./outbound-guard_test.sh
#
# Covers the judgement half of spec.md section 8. The rest (does the dialog
# reach a human under `auto`, does a broken script fall open) can only be seen
# in a live session.

cd "$(dirname "$0")" || exit 1
GUARD=./outbound-guard.sh
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT

make_repo() { # make_repo <dir> <remote-url> [extra-remote-url]
    git init -q "$1" && git -C "$1" remote add origin "$2"
    [ -n "$3" ] && git -C "$1" remote add fork "$3"
    return 0
}
TN=$WORK/task-notes
ORG=$WORK/org
BOTH=$WORK/two-remotes
PLAIN=$WORK/plain
make_repo "$TN"  https://github.com/hskwakr/task-notes.git
make_repo "$ORG" git@github.com:evetech-jp/oripa-backend-infra.git
make_repo "$BOTH" https://github.com/hskwakr/task-notes.git git@github.com:someone/fork.git
mkdir -p "$PLAIN"

pass=0; fail=0
t() { # t <pass|ask> <command> [cwd]
    local want=$1 cmd=$2 cwd=${3:-$TN} out got
    out=$(jq -nc --arg c "$cmd" --arg d "$cwd" \
        '{session_id:"t",cwd:$d,hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' \
        | "$GUARD")
    if [ -z "$out" ]; then got=pass
    elif printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1; then got=ask
    else got="malformed:$out"; fi
    if [ "$got" = "$want" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL want=%-4s got=%-4s  %s\n' "$want" "$got" "$cmd"
        [ -n "$out" ] && printf '        reason: %s\n' \
            "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"
    fi
}

echo "== target resolution (spec 4.1) =="
t pass 'git push'                                                         "$TN"
t ask  'git push'                                                         "$ORG"
t ask  'git push origin main'                                             "$ORG"
t ask  'git push git@github.com:evetech-jp/oripa-backend-infra.git main'  "$TN"
t pass 'git push https://github.com/hskwakr/task-notes.git main'          "$ORG"
t ask  'gh pr edit -R evetech-jp/oripa-backend-infra 2028 --base dev'     "$TN"
t pass 'gh pr edit -R hskwakr/task-notes 1 --title x'                     "$ORG"
t ask  'gh pr comment https://github.com/o/r/issues/1 --body hi'          "$TN"
t ask  'GH_REPO=o/r gh pr close 1'                                        "$TN"
t ask  'gh api -X PATCH repos/o/r/pulls/1'                                "$TN"
t ask  'git -C '"$ORG"' push'                                             "$TN"
t ask  'git push --repo=git@github.com:evetech-jp/x.git main'             "$TN"
t ask  'git push --repo git@github.com:evetech-jp/x.git main'             "$TN"
t pass 'cd '"$TN"' && git push'                                           "$ORG"

echo "== shell variables (spec 4.3) =="
t pass 'R='"$TN"'; cd $R && git push'                                     "$ORG"
t ask  'R='"$ORG"'; cd $R && git push'                                    "$TN"
t ask  'cd $R && git push'                                                "$TN"
t ask  'R=/a; cd $R && git push; R=/b'                                    "$TN"
t ask  'R=$(pwd); cd $R && git push'                                      "$TN"
t pass 'W='"$TN"' && git -C "$W" push'                                    "$ORG"
t ask  'echo " R='"$ORG"' "; cd $R && git push'                           "$TN"

echo "== gh api effective method (spec 3.2) =="
t pass 'gh api -X GET search/code -f q=foo'                               "$TN"
t pass 'gh api repos/o/r --jq .full_name'                                 "$TN"
t pass 'for r in a/b c/d; do gh api repos/$r --jq .name; done'            "$TN"
t ask  'gh api repos/o/r -f body=hi'                                      "$TN"
t ask  'gh api --method POST repos/o/r/issues -f title=x'                 "$TN"
t ask  'gh api graphql -f query=mutation'                                 "$TN"
t ask  'gh api -X POST user/repos -f name=x'                              "$TN"

echo "== read-only stays silent (spec 3.3) =="
t pass 'gh pr view 12'
t pass 'gh pr list --repo evetech-jp/oripa-backend-infra'
t pass 'git fetch origin && git status'
t pass 'gh search code --owner evetech-jp foo'
t pass 'ls -la && cat README.md'
t pass 'gh run list --repo evetech-jp/oripa-backend-infra --limit 5'

echo "== heredoc bodies are prose (spec 3.0) =="
t pass 'cat <<EOF > /tmp/note
remember to git push origin main
EOF'
t pass "gh pr create --body \"\$(cat <<'MD'
then run: git push -u origin HEAD
MD
)\" --repo hskwakr/task-notes"

# A2: a `<<` that opens nothing must not swallow what follows it.
t ask  'grep -n "<<EOF" notes.md
git push'                                                                 "$ORG"
t ask  '# see <<EOF below
git push'                                                                 "$ORG"
t ask  'cat <<< "$msg"
git push'                                                                 "$ORG"
t ask  'cat <<EOF
never terminated
git push'                                                                 "$ORG"
t pass "gh pr comment 1 --body \"\$(cat <<'MD'
run: git push
MD
)\" -R hskwakr/task-notes"

echo "== commands hidden from the tokenizer =="
t ask  'bash -c "cd '"$ORG"' && git push"'                                "$TN"
t pass 'bash -lc "gh pr list --repo hskwakr/task-notes --json number"'    "$TN"
t ask  'ssh host "git push"'                                              "$TN"
t pass 'curl -H "Authorization: Bearer $(gh auth token)" https://x'       "$TN"
t ask  'echo $(git push origin main)'                                     "$ORG"
t ask  'sudo git push'                                                    "$ORG"
t ask  'for x in a; do git push; done'                                    "$ORG"

echo "== nothing reached a handler, so silence means ask =="
# Listing the wrappers that front another command never finishes: caffeinate,
# nice, parallel and find -exec all hid a push. Anything that still reads as
# outbound after the walk found no git, gh or npm to attribute it to asks.
t ask  'caffeinate -i git push origin main'                               "$TN"
t ask  'nice -n 10 git push'                                              "$TN"
t ask  'parallel git push ::: a'                                          "$TN"
t ask  'find . -name x -exec git push \;'                                 "$TN"
t ask  'ssh box git push origin main'                                     "$TN"
# The cost of that rule: prose naming a push now asks. Measured at 16 commands
# in 17,282 of recorded history, against 64 the guard already asked about.
t ask  'timeout 120 rg -o "git -C \$W push" .'                            "$TN"
t ask  'grep -c "git push" f.txt'                                         "$TN"

echo "== a command substitution in an assignment still runs (A1) =="
t ask  'PR_URL=$(gh pr create -R evetech-jp/oripa-backend-infra --title x)' "$TN"
t pass 'S=$(gh pr view 78 --json mergeable -q .mergeable)'                "$TN"
t pass 'for i in 1 2 3; do s=$(gh pr view 78 --json state); done'         "$TN"

echo "== gh writes the table had not heard of (A10) =="
t ask  'gh repo archive evetech-jp/oripa-backend-infra --yes'
t ask  'gh repo unarchive evetech-jp/oripa-backend-infra'
t ask  'gh repo rename new-name -R evetech-jp/oripa-backend-infra'
t ask  'gh repo deploy-key add key.pub -R evetech-jp/oripa-backend-infra'
t ask  'gh label create bug -R evetech-jp/oripa-backend-infra'
t ask  'gh cache delete 1 -R evetech-jp/oripa-backend-infra'
t ask  'gh pr revert 1 -R evetech-jp/oripa-backend-infra'
# `gh gist` resolves by cwd like every other repo-scoped verb, so a gist write
# from inside task-notes passes. Whether a gist is an outbound target at all is
# a spec question, not a table one -- left alone here.
t pass 'gh gist rename g a b'
t pass 'gh label list -R hskwakr/task-notes'
t pass 'gh cache list'
t pass 'gh ruleset check'
t pass 'gh pr --help'
t pass 'gh --version'

echo "== always ask, no repository to resolve (spec 4.4) =="
t ask  'npm publish'
t ask  'gh repo create foo --private'
t ask  'gh repo delete o/r --yes'

echo "== degraded and unresolvable (spec 4.2, 5) =="
t ask  'git push'                                                         "$PLAIN"
t ask  'git push'                                                         /nonexistent/dir
t ask  'git push'                                                         "$BOTH"
t ask  'GIT_DIR=/elsewhere/.git git push'                                 "$TN"
t ask  'git push upstream main'                                           "$TN"


echo "== the push URL is git's answer, not remote.<n>.url (B1, C9, B5) =="
# Each of these leaves remote.origin.url pointing at task-notes and moves the
# push destination somewhere else through a different config key. Reading
# remote.<n>.url by hand saw task-notes in all three.
ORG_URL=git@github.com:evetech-jp/oripa-backend-infra.git
PUSHURL=$WORK/pushurl
make_repo "$PUSHURL" https://github.com/hskwakr/task-notes.git
git -C "$PUSHURL" config remote.origin.pushurl "$ORG_URL"
t ask  'git push'                                                         "$PUSHURL"
t ask  'git push origin main'                                             "$PUSHURL"

INSTEAD=$WORK/pushinsteadof
make_repo "$INSTEAD" https://github.com/hskwakr/task-notes.git
git -C "$INSTEAD" config url.https://github.com/evetech-jp/.pushInsteadOf https://github.com/hskwakr/
t ask  'git push'                                                         "$INSTEAD"

# `git config --local` does not include the --worktree scope, so a remote
# swapped there was invisible.
WTMAIN=$WORK/wt-main
make_repo "$WTMAIN" https://github.com/hskwakr/task-notes.git
git -C "$WTMAIN" commit -q --allow-empty -m init
git -C "$WTMAIN" config extensions.worktreeConfig true
git -C "$WTMAIN" worktree add -q "$WORK/wt-side" -b side
git -C "$WORK/wt-side" config --worktree remote.origin.url "$ORG_URL"
t pass 'git push'                                                         "$WTMAIN"
t ask  'git push'                                                         "$WORK/wt-side"

echo "== a remote name is not a shell variable name (B2) =="
# The map used to live in variable names via eval, so every name outside
# [A-Za-z0-9_] was dropped -- both the lookup and the all-remotes check.
HYPHEN=$WORK/hyphen
make_repo "$HYPHEN" https://github.com/hskwakr/task-notes.git
git -C "$HYPHEN" remote add my-fork "$ORG_URL"
git -C "$HYPHEN" remote add my.dots "$ORG_URL"
t ask  'git push my-fork main'                                            "$HYPHEN"
t ask  'git push my.dots main'                                            "$HYPHEN"
t ask  'git push'                                                         "$HYPHEN"

HYPHEN_TN=$WORK/hyphen-tn
make_repo "$HYPHEN_TN" https://github.com/hskwakr/task-notes.git
git -C "$HYPHEN_TN" remote add my-mirror https://github.com/hskwakr/task-notes.git
t pass 'git push my-mirror main'                                          "$HYPHEN_TN"

echo "== gh-resolved names a repository, not just a remote (B9) =="
# `gh repo set-default` writes either "base" or an owner/repo, and the second
# form need not have a remote at all (cli/cli pkg/cmd/factory/default.go).
# Reading only the key name answered with that remote's own URL.
RESOLVED=$WORK/gh-resolved
make_repo "$RESOLVED" https://github.com/hskwakr/task-notes.git
git -C "$RESOLVED" config remote.origin.gh-resolved evetech-jp/oripa-backend-infra
t ask  'gh pr create --fill'                                              "$RESOLVED"
t ask  'git push'                                                         "$RESOLVED"

RESOLVED_BASE=$WORK/gh-resolved-base
make_repo "$RESOLVED_BASE" https://github.com/hskwakr/task-notes.git
git -C "$RESOLVED_BASE" config remote.origin.gh-resolved base
t pass 'gh pr create --fill'                                              "$RESOLVED_BASE"

echo "== flags that move the repository out from under the cwd (A4) =="
# GIT_DIR and GIT_WORK_TREE already forced an ask; the flag spellings were read
# and thrown away, so the cwd answered for a repository git never looked at.
t ask  'git --git-dir='"$ORG"'/.git --work-tree='"$ORG"' push'            "$TN"
t ask  'git --git-dir '"$ORG"'/.git --work-tree '"$ORG"' push'            "$TN"
t ask  'git --work-tree='"$ORG"' push'                                    "$TN"
t pass 'git --namespace=ns push'                                          "$TN"
t pass 'git --git-dir='"$ORG"'/.git status'                               "$TN"

echo "== git submodule foreach runs elsewhere (A9) =="
# A submodule has remotes of its own, so the superproject's cwd says nothing
# about where the push lands. `submodule` is not `push`, so nothing was emitted.
t ask  'git submodule foreach git push'                                   "$TN"
t ask  'git submodule foreach '"'"'git push origin HEAD'"'"''             "$TN"
t ask  'git -C '"$TN"' submodule foreach git push'                        "$ORG"
t pass 'git submodule update --init --recursive'                          "$TN"
t pass 'git submodule status'                                             "$TN"

echo "== gh api body flags written as one token (B7) =="
# gh accepts -ftitle=x as well as -f title=x. Only the split form was counted,
# so the attached form left the effective method at GET and read as a read.
t ask  'gh api -ftitle=x repos/o/r/issues'                                "$TN"
t ask  'gh api -Fbody=@f repos/o/r/issues'                                "$TN"
t pass 'gh api -ftitle=x repos/hskwakr/task-notes/issues'                 "$ORG"
t pass 'gh api -X GET search/code -fq=foo'                                "$TN"

echo "== gh api can name another host (B10) =="
# --hostname and an absolute endpoint both send the request somewhere other
# than github.com, and the owner/repo alone cannot tell.
t ask  'gh api --hostname ghe.example.com -X PATCH repos/hskwakr/task-notes/pulls/1' "$TN"
t ask  'gh api --hostname=ghe.example.com -X PATCH repos/hskwakr/task-notes/pulls/1' "$TN"
t ask  'gh api -X PATCH https://ghe.example.com/api/v3/repos/hskwakr/task-notes/pulls/1' "$TN"
t ask  'gh api --hostname $H -X PATCH repos/hskwakr/task-notes/pulls/1'   "$TN"
t ask  'gh api --hostname ghe.example.com -X POST repos/{owner}/{repo}/issues' "$TN"
t pass 'gh api --hostname ghe.example.com -X GET repos/o/r'               "$TN"

echo "== a push that carries its submodules along =="
# --recurse-submodules=on-demand|only, push.recurseSubmodules and
# submodule.recurse all send each changed submodule to a remote of its own,
# which is not among the ones configured in this directory.
t ask  'git push --recurse-submodules=on-demand'                          "$TN"
t ask  'git push --recurse-submodules=only origin main'                   "$TN"
t ask  'git push --recurse-submodules on-demand'                          "$TN"
t pass 'git push --recurse-submodules=check'                              "$TN"
t pass 'git push --recurse-submodules=no origin main'                     "$TN"
t pass 'git push --no-recurse-submodules'                                 "$TN"

SUBMOD=$WORK/submod
make_repo "$SUBMOD" https://github.com/hskwakr/task-notes.git
: > "$SUBMOD/.gitmodules"
git -C "$SUBMOD" config push.recurseSubmodules on-demand
t ask  'git push'                                                         "$SUBMOD"

SUBMOD2=$WORK/submod2
make_repo "$SUBMOD2" https://github.com/hskwakr/task-notes.git
: > "$SUBMOD2/.gitmodules"
git -C "$SUBMOD2" config submodule.recurse true
t ask  'git push'                                                         "$SUBMOD2"
git -C "$SUBMOD2" config submodule.recurse false
t pass 'git push'                                                         "$SUBMOD2"

# The configuration only matters where there is a submodule to carry.
NOSUB=$WORK/nosub
make_repo "$NOSUB" https://github.com/hskwakr/task-notes.git
git -C "$NOSUB" config push.recurseSubmodules on-demand
t pass 'git push'                                                         "$NOSUB"

echo "== a heredoc handed to a shell is commands, not prose (A8b) =="
# Heredoc bodies are stripped because PR bodies quote `git push` -- but a body
# fed to bash is the command itself, and it went out with the prose.
t ask  "$(printf 'bash <<EOF\ngit push\nEOF')"                            "$ORG"
t pass "$(printf 'bash <<EOF\ngit push\nEOF')"                            "$TN"
t ask  "$(printf 'cat <<EOF | bash\ngit push\nEOF')"                      "$ORG"
t pass "$(printf 'cat <<EOF > /dev/null\ngit push\nEOF')"                 "$ORG"
t pass "$(printf 'gh pr create --body \"$(cat <<EOF\nrun git push here\nEOF\n)\"')" "$TN"

echo "== a subshell gives the working directory back (B6) =="
# The cd inside the parentheses dies with the subshell, so the command after it
# runs where the line began -- the guard used to carry the cd out with it.
t ask  '(cd '"$TN"' && git push) && git push'                             "$ORG"
t ask  '( cd '"$TN"'; git push ) ; git push'                              "$ORG"
t pass '(cd '"$ORG"' && git status) && git push'                          "$TN"
t pass '(cd '"$TN"' && git push)'                                         "$ORG"

echo "== the destination of a transfer is a positional (B11) =="
# `gh issue transfer <number|url> <destination>`: -R names the repository the
# issue leaves, and the one it lands in is never a flag.
t ask  'gh issue transfer 2028 evetech-jp/oripa-backend-infra'            "$TN"
t ask  'gh issue transfer https://github.com/hskwakr/task-notes/issues/1 evetech-jp/x' "$TN"
t ask  'gh issue transfer -R hskwakr/task-notes 1 evetech-jp/x'           "$TN"
t ask  'gh issue transfer 1 evetech-jp/x -R hskwakr/task-notes'           "$TN"
t pass 'gh issue transfer 1 hskwakr/task-notes'                           "$TN"

echo "== a remote rewritten in the same line (B15) =="
# The guard reads the configuration before the command runs, so a set-url
# earlier on the line makes every directory-derived answer stale.
t ask  'git remote set-url origin git@github.com:evetech-jp/x.git && git push' "$TN"
t ask  'git remote rename origin old && git push'                         "$TN"
t pass 'git remote set-url origin git@github.com:evetech-jp/x.git'        "$TN"
t pass 'git remote -v && git push'                                        "$TN"
t pass 'git remote set-url origin git@github.com:evetech-jp/x.git && git push https://github.com/hskwakr/task-notes.git main' "$TN"

echo "== a damaged analyser must not fall open (C3) =="
# An empty or truncated .awk still parses and exits 0 with no output, which is
# byte-for-byte what "nothing outbound here" looks like. Only the closing
# marker separates them.
COPY=$WORK/copy
mkdir -p "$COPY"
cp outbound-guard.sh outbound-guard.awk "$COPY/" && chmod +x "$COPY/outbound-guard.sh"
damaged() { # damaged <label> <how-to-write-the-awk>
    local label=$1 out got
    eval "$2"
    out=$(jq -nc --arg c 'git push' --arg d "$ORG" \
        '{session_id:"t",cwd:$d,hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' \
        | "$COPY/outbound-guard.sh")
    if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1
    then pass=$((pass + 1))
    else fail=$((fail + 1)); printf 'FAIL want=ask  got=%-4s  analyser %s\n' "${out:-pass}" "$label"
    fi
    cp outbound-guard.awk "$COPY/outbound-guard.awk"
}
damaged "empty"                ': > "$COPY/outbound-guard.awk"'
damaged "cut at a function end" 'head -n "$(grep -n "^}" outbound-guard.awk | cut -d: -f1 | head -1)" outbound-guard.awk > "$COPY/outbound-guard.awk"'
damaged "missing"              'rm -f "$COPY/outbound-guard.awk"'
damaged "not valid awk"        'printf "function f( {\n" > "$COPY/outbound-guard.awk"'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
