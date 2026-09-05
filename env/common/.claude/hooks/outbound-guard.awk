# Reads a Bash command on stdin and prints one fact per outbound invocation.
#
#   REPO <host>  <owner/repo>  <what>     target known from the command itself
#   PATH <dir>   <remote|->    <what>     caller must ask git which repo <dir> is
#   ASK  <reason>                         cannot be resolved; caller must ask
#
# Every uncertainty becomes ASK. Resolving wrongly would let an outbound command
# through, so this file never guesses.
#
# Environment: GUARD_CWD (the hook's cwd), HOME.

function fail(reason) { print "ASK\t" reason; found = 1; reached = 1 }
function nest(text, what) {
    gsub(/\n/, ";", text); gsub(/\t/, " ", text)
    print "NEST\t" text "\t" what; reached = 1
}

# The shell text inside $(...) or `...`, with the wrapper removed.
function inner_of(t,   s) {
    s = t
    if (match(s, /\$\(/)) {
        s = substr(s, RSTART + 2)
        sub(/\)[^)]*$/, "", s)
    } else if (index(s, "`") > 0) {
        s = substr(s, index(s, "`") + 1)
        sub(/`.*$/, "", s)
    }
    return s
}
function repo_fact(host, nwo, what) { print "REPO\t" host "\t" nwo "\t" what; found = 1 }
function path_fact(dir, remote, what) { print "PATH\t" dir "\t" remote "\t" what; found = 1; found_path = 1 }

# ---------------------------------------------------------------- heredocs
# A heredoc body is prose, not commands. PR bodies and task notes routinely
# quote `git push`, and matching inside them produced 38 false positives over
# the 26-day sample.
# Collects the delimiters `line` opens into HD[1..HDN]. A `<<` inside quotes or
# after `#` opens nothing, and `<<<` is a herestring. Reading those as heredocs
# swallowed the rest of the command -- the commonest way a `git push` vanished.
function scan_heredoc_openers(line,   n, i, c, k, sp, d, q) {
    HDN = 0; n = length(line); i = 1; sp = 0
    # ST[1..sp] are the open contexts: "'", "\"", "(" for $(...), "`" for `...`.
    # $(...) inside a double quote is unquoted again, which is exactly the shape
    # `--body "$(cat <<'EOF'` takes -- the commonest heredoc in this corpus.
    while (i <= n) {
        c = substr(line, i, 1)
        k = (sp > 0) ? ST[sp] : ""

        if (k == "'") { if (c == "'") sp--; i++; continue }
        if (c == "\\") { i += 2; continue }
        if (k == "\"") {
            if (c == "\"") sp--
            else if (c == "$" && substr(line, i + 1, 1) == "(") { ST[++sp] = "("; i++ }
            else if (c == "`") ST[++sp] = "`"
            i++
            continue
        }

        if (c == "'" || c == "\"") { ST[++sp] = c; i++; continue }
        if (c == "$" && substr(line, i + 1, 1) == "(") { ST[++sp] = "("; i += 2; continue }
        if (c == "`") { if (k == "`") sp--; else ST[++sp] = "`"; i++; continue }
        if (c == ")" && k == "(") { sp--; i++; continue }
        if (c == "#" && sp == 0 && (i == 1 || substr(line, i - 1, 1) ~ /[ \t;&|(]/)) break
        if (c != "<" || substr(line, i + 1, 1) != "<") { i++; continue }
        if (substr(line, i + 2, 1) == "<") { i += 3; continue }

        i += 2
        HDN++
        HDDASH[HDN] = 0
        if (substr(line, i, 1) == "-") { HDDASH[HDN] = 1; i++ }
        while (i <= n && substr(line, i, 1) ~ /[ \t]/) i++
        d = ""
        while (i <= n) {
            c = substr(line, i, 1)
            if (c ~ /[ \t;&|()<>]/) break
            if (c == "\\") { d = d substr(line, i + 1, 1); i += 2; continue }
            if (c == "'" || c == "\"") {
                q = c; i++
                while (i <= n && substr(line, i, 1) != q) { d = d substr(line, i, 1); i++ }
                i++
                continue
            }
            d = d c; i++
        }
        if (d == "") HDN--
        else HD[HDN] = d
    }
}

function strip_heredocs(   i, j, k, np, line, out, closed, opener, body) {
    out = ""
    i = 1
    while (i <= nline) {
        line = L[i]
        out = out line "\n"
        opener = line
        scan_heredoc_openers(line)
        if (HDN == 0) { i++; continue }

        np = HDN
        for (k = 1; k <= np; k++) PD[k] = HD[k]

        j = i + 1
        closed = 1
        body = ""
        for (k = 1; k <= np && closed; k++) {
            closed = 0
            while (j <= nline) {
                line = L[j]
                gsub(/^[ \t]+|[ \t]+$/, "", line)
                j++
                if (line == PD[k]) { closed = 1; break }
                body = body L[j - 1] "\n"
            }
        }
        # An unterminated delimiter means this was not a heredoc after all.
        # Dropping the rest would hide whatever follows, so keep reading.
        if (closed) {
            # A body handed to a shell is commands, not prose. Dropping it with
            # the rest is what let `bash <<EOF ... git push ... EOF` through.
            if (opener ~ /(^|[ \t;&|(])(bash|sh|zsh|dash|ksh|eval)([ \t]|$)/ && looks_outbound(body))
                HDBODY = HDBODY body
            i = j
        }
        else i++
    }
    return out
}

# ---------------------------------------------------------------- tokenizer
# Splits into words and operators. Quotes are removed but `$` is kept: this
# never expands anything, it only decides whether expansion is knowable.
function scan_word(s, i,   n, c, depth) {
    n = length(s); W_TEXT = ""; W_SQVAR = 0
    while (i <= n) {
        c = substr(s, i, 1)
        if (c == " " || c == "\t" || c == "\n" || c == ";" || c == "&" ||
            c == "|" || c == "(" || c == ")" || c == "<" || c == ">") break
        if (c == "\\") { W_TEXT = W_TEXT substr(s, i + 1, 1); i += 2; continue }
        if (c == "'") {
            i++
            while (i <= n && substr(s, i, 1) != "'") {
                c = substr(s, i, 1)
                if (c == "$") W_SQVAR = 1      # literal `$`, not an expansion
                W_TEXT = W_TEXT c; i++
            }
            i++
            continue
        }
        if (c == "\"") {
            i++
            while (i <= n && substr(s, i, 1) != "\"") {
                if (substr(s, i, 1) == "\\") { W_TEXT = W_TEXT substr(s, i + 1, 1); i += 2; continue }
                W_TEXT = W_TEXT substr(s, i, 1); i++
            }
            i++
            continue
        }
        if (c == "$" && substr(s, i + 1, 1) == "(") {   # keep $(...) in one piece
            depth = 0
            while (i <= n) {
                c = substr(s, i, 1)
                W_TEXT = W_TEXT c
                if (c == "(") depth++
                else if (c == ")") { i++; if (--depth == 0) break; continue }
                i++
            }
            continue
        }
        if (c == "`") {
            W_TEXT = W_TEXT c; i++
            while (i <= n && substr(s, i, 1) != "`") { W_TEXT = W_TEXT substr(s, i, 1); i++ }
            W_TEXT = W_TEXT "`"; i++
            continue
        }
        W_TEXT = W_TEXT c; i++
    }
    W_END = i
    return i
}

function skip_redir(s, i,   n, c) {
    n = length(s)
    while (i <= n) {
        c = substr(s, i, 1)
        if (c == "<" || c == ">" || c == "&" || c == "-" || c ~ /[0-9]/) { i++; continue }
        break
    }
    while (i <= n && (substr(s, i, 1) == " " || substr(s, i, 1) == "\t")) i++
    c = substr(s, i, 1)
    if (i <= n && c != "" && c != "\n" && c != ";" && c != "&" && c != "|" &&
        c != "(" && c != ")" && c != "<" && c != ">") i = scan_word(s, i)
    return i
}

function addtok(text, pos, isop, sqvar) {
    ntok++; T[ntok] = text; TP[ntok] = pos; TOP[ntok] = isop; TSQ[ntok] = sqvar
}

function tokenize(s,   n, i, c, start) {
    ntok = 0; n = length(s); i = 1
    while (i <= n) {
        c = substr(s, i, 1)
        if (c == " " || c == "\t") { i++; continue }
        if (c == "\\" && substr(s, i + 1, 1) == "\n") { i += 2; continue }
        if (c == "&" && substr(s, i + 1, 1) == ">") { i = skip_redir(s, i); continue }
        if (c == "<" || c == ">") { i = skip_redir(s, i); continue }
        if (c == "\n" || c == ";" || c == "&" || c == "|" || c == "(" || c == ")") {
            if (c == "&" && substr(s, i + 1, 1) == "&") { addtok("&&", i, 1, 0); i += 2; continue }
            if (c == "|" && substr(s, i + 1, 1) == "|") { addtok("||", i, 1, 0); i += 2; continue }
            addtok(c, i, 1, 0); i++
            continue
        }
        start = i
        i = scan_word(s, i)
        # `2>&1`: a bare digit run that turns out to introduce a redirection
        if (W_TEXT ~ /^[0-9]+$/ && (substr(s, i, 1) == "<" || substr(s, i, 1) == ">")) {
            i = skip_redir(s, i); continue
        }
        addtok(W_TEXT, start, 0, W_SQVAR)
    }
}

# ------------------------------------------------- assignments and lookups
# Marks each token that starts a simple command, then records the literal
# assignments sitting in those command positions.
function scan_assignments(   i, atstart, name, val, k) {
    atstart = 1
    for (i = 1; i <= ntok; i++) {
        if (TOP[i]) { atstart = 1; continue }
        HEAD[i] = atstart
        if (atstart && T[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
            k = index(T[i], "=")
            name = substr(T[i], 1, k - 1)
            val = substr(T[i], k + 1)
            ACOUNT[name]++
            APOS[name] = i
            AVAL[name] = (val == "" || val ~ /\$/ || index(val, "`") > 0 || TSQ[i]) ? BAD : val
            continue                      # still at a command position
        }
        atstart = 0
    }
}

# The one literal assignment to `name` that is visible from token `usetok`.
function lookup(name, usetok) {
    if (ACOUNT[name] != 1) return BAD      # absent, or reassigned
    if (AVAL[name] == BAD) return BAD      # not a literal
    if (APOS[name] > usetok) return BAD    # assigned after this use
    return AVAL[name]
}

# Substitutes $VAR / ${VAR} in `tok` using those assignments. Returns BAD unless
# the whole token resolves: a partly-resolved path is a wrong path.
function resolve(tok, usetok,   out, guard, ref, name, val) {
    if (tok ~ /\$\(/ || index(tok, "`") > 0) return BAD
    if (TSQ[usetok]) return (tok ~ /\$/) ? BAD : tok
    if (has_control) return (tok ~ /\$/) ? BAD : tok
    out = tok; guard = 0
    while (match(out, /\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/)) {
        if (++guard > 16) return BAD
        ref = substr(out, RSTART, RLENGTH)
        name = ref; gsub(/[${}]/, "", name)
        val = lookup(name, usetok)
        if (val == BAD) return BAD
        out = substr(out, 1, RSTART - 1) val substr(out, RSTART + RLENGTH)
    }
    if (out == "" || out ~ /\$/) return BAD
    return out
}

function detect_control(   i) {
    for (i = 1; i <= ntok; i++) {
        if (TOP[i] || !HEAD[i]) continue
        if (T[i] ~ /^(if|then|else|elif|fi|for|while|until|do|done|case|esac|select|function)$/) return 1
        if (T[i] ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && TOP[i + 1] && T[i + 1] == "(" &&
            TOP[i + 2] && T[i + 2] == ")") return 1
    }
    return 0
}

# --------------------------------------------------------------- matching
# Deliberately loose: used only to decide whether something outbound might be
# hiding inside a string we are not going to tokenize (a `bash -c` argument,
# a command substitution). False positives here cost one dialog.
function looks_outbound(s) {
    return (s ~ /(^|[^A-Za-z0-9_-])git([^A-Za-z0-9_-].*)?[ \t]push([^A-Za-z0-9_-]|$)/ ||
            s ~ /(^|[^A-Za-z0-9_-])gh[ \t]/ ||
            s ~ /(^|[^A-Za-z0-9_-])npm[ \t]+publish([^A-Za-z0-9_-]|$)/)
}

function basename(p) { sub(/^.*\//, "", p); return p }

# owner/repo out of a remote URL or a `-R` value. Sets R_HOST and R_NWO.
function parse_repo(u,   s, host, rest, n, parts) {
    R_HOST = ""; R_NWO = ""
    if (u == "" || u ~ /\$/ || u ~ /\$\(/ || index(u, "`") > 0) return 0
    s = u
    sub(/\/+$/, "", s)
    sub(/\.git$/, "", s)
    if (s ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\//) {            # scheme://[user@]host/path
        sub(/^[A-Za-z][A-Za-z0-9+.-]*:\/\//, "", s)
        sub(/^[^\/@]*@/, "", s)
        host = s; sub(/[\/:].*$/, "", host)
        rest = s; sub(/^[^\/]*\//, "", rest)
    } else if (s ~ /^[^\/]*@[^\/]*:/) {                   # user@host:owner/repo
        sub(/^[^@]*@/, "", s)
        host = s; sub(/:.*$/, "", host)
        rest = s; sub(/^[^:]*:/, "", rest)
        sub(/^\/+/, "", rest)
    } else if (s ~ /^[A-Za-z0-9.-]+\.[A-Za-z]+\/[^\/]+\/[^\/]+/) {  # host/owner/repo
        host = s; sub(/\/.*$/, "", host)
        rest = s; sub(/^[^\/]*\//, "", rest)
    } else if (s ~ /^\/?[^\/]+\/[^\/]+/) {                # owner/repo
        host = "github.com"
        rest = s; sub(/^\//, "", rest)
    } else return 0
    n = split(rest, parts, "/")
    if (n < 2 || parts[1] == "" || parts[2] == "") return 0
    R_HOST = tolower(host)
    R_NWO = tolower(parts[1] "/" parts[2])
    return 1
}

function is_url(s) { return (s ~ /:\/\// || s ~ /^[^\/ ]*@[^\/ ]*:/) }

function join_path(base, p) {
    if (p == BAD || base == BAD) return BAD
    if (p == "-" || p == "") return BAD                   # `cd -` needs history
    if (substr(p, 1, 1) == "/") return p
    if (substr(p, 1, 1) == "~") return ENVIRON["HOME"] substr(p, 2)
    if (base == "") base = ENVIRON["GUARD_CWD"]
    if (base == "") return BAD
    return base "/" p
}

# ------------------------------------------------------------------- walk
function argv_end(i,   j) {
    j = i
    while (j <= ntok && !TOP[j]) j++
    return j - 1
}

# Shell keywords occupy the head slot without being a command. Stepping over
# them keeps `for f in ...; do git push; done` from hiding the push.
function is_keyword(h) {
    return (h ~ /^(if|then|else|elif|fi|for|while|until|do|done|case|esac|select|\{|\}|!)$/)
}

# These run a *string* as shell, so the command inside has to be analysed on
# its own terms.
function runs_a_string(h) {
    return (h ~ /^(bash|sh|zsh|dash|ksh|eval)$/)
}

# These take an argv, so the real command is simply further along the line.
# `timeout 120 rg 'git push'` must not be read as a push.
function fronts_a_command(h) {
    return (h ~ /^(env|xargs|nohup|time|timeout|sudo|doas|command|builtin|exec)$/)
}

function handle_git(i, e,   j, sub_, path, remote, t, moved, rest, rj, rv) {
    path = ""; remote = ""; sub_ = ""; moved = 0
    j = i + 1
    while (j <= e) {
        t = T[j]
        if (t == "-C" || t == "--git-dir" || t == "--work-tree" || t == "--namespace" ||
            t == "-c" || t == "--exec-path" || t == "--super-prefix") {
            if (t == "-C" && j + 1 <= e) path = resolve(T[j + 1], j + 1)
            if (t == "--git-dir" || t == "--work-tree") moved = 1
            j += 2; continue
        }
        if (t ~ /^--(git-dir|work-tree)=/) { moved = 1; j++; continue }
        if (t ~ /^--(namespace|exec-path|super-prefix)=/) { j++; continue }
        if (t ~ /^-/) { j++; continue }
        sub_ = t; break
    }
    # `git submodule foreach <cmd>` runs <cmd> in each submodule, which has
    # remotes of its own. The working directory says nothing about them.
    if (sub_ == "submodule") {
        rest = ""
        for (j = j + 1; j <= e; j++) rest = rest " " T[j]
        if (looks_outbound(rest)) fail("git submodule: runs an outbound command in each submodule, which has its own remotes:" rest)
        return
    }
    # `git remote set-url origin <org> && git push` leaves the guard reading the
    # configuration from before the rewrite. Only answers that came from a
    # directory are stale; an explicit URL or -R still says where it goes.
    if (sub_ == "remote") {
        t = (j + 1 <= e) ? T[j + 1] : ""
        if (t ~ /^(add|remove|rm|rename|set-url|set-head|set-branches)$/) remote_rewritten = 1
        return
    }
    if (sub_ != "push") return
    # These move the repository out from under the working directory, the same
    # way GIT_DIR and GIT_WORK_TREE do, so they get the same answer.
    if (moved) { fail("git push: --git-dir or --work-tree moves the target repository"); return }
    # `--recurse-submodules=on-demand` and `=only` send each changed submodule to
    # a remote of its own, which the working directory does not name. The same
    # goes for push.recurseSubmodules and submodule.recurse, which the caller
    # reads off the repository.
    for (rj = j + 1; rj <= e; rj++) {
        if (T[rj] ~ /^--recurse-submodules=/) rv = substr(T[rj], index(T[rj], "=") + 1)
        else if (T[rj] == "--recurse-submodules") rv = (rj + 1 <= e) ? T[rj + 1] : ""
        else continue
        if (rv == "on-demand" || rv == "only") {
            fail("git push --recurse-submodules=" rv ": also pushes each changed submodule, which has a remote of its own")
            return
        }
    }
    # the first positional after `push` names the remote
    for (j = j + 1; j <= e; j++) {
        t = T[j]
        if (t ~ /^--repo=/) { remote = resolve(substr(t, 8), j); break }
        if (t == "--repo") { if (j + 1 <= e) remote = resolve(T[j + 1], j + 1); break }
        if (t == "-o" || t == "--push-option" || t == "--receive-pack" ||
            t == "--exec" || t == "--signed" || t == "--recurse-submodules") { j++; continue }
        if (t ~ /^-/) continue
        remote = resolve(t, j)
        break
    }
    if (path == BAD) { fail("git push: -C path uses a shell variable that cannot be resolved"); return }
    if (path == "") path = eff_cwd
    else path = join_path(eff_cwd, path)
    if (remote == BAD) { fail("git push: remote argument uses a shell variable that cannot be resolved"); return }
    if (remote != "" && is_url(remote)) {
        if (parse_repo(remote)) repo_fact(R_HOST, R_NWO, "git push " remote)
        else fail("git push: cannot read a repository out of the remote URL " remote)
        return
    }
    if (path == BAD) { fail("git push: working directory uses a shell variable that cannot be resolved"); return }
    path_fact(path == "" ? ENVIRON["GUARD_CWD"] : path, remote == "" ? "-" : remote, "git push")
}

function gh_flag_repo(i, e,   j, t, v) {
    for (j = i; j <= e; j++) {
        t = T[j]
        if (t == "-R" || t == "--repo") { if (j + 1 <= e) return resolve(T[j + 1], j + 1); return BAD }
        if (t ~ /^--repo=/) { v = substr(t, 8); return resolve(v, j) }
        if (t ~ /^-R./) { v = substr(t, 3); return resolve(v, j) }
    }
    return ""
}

function gh_positional_url(i, e,   j, t) {
    for (j = i; j <= e; j++) {
        t = T[j]
        if (t ~ /^-/) continue
        if (is_url(t)) return resolve(t, j)
    }
    return ""
}

# `gh api` is a write unless the effective method is GET. Body flags imply POST
# only when no method is given -- gh's own rule. Treating -f/-F as a write on
# its own turned 91 `gh api -X GET search/code` calls into dialogs.
function gh_api_method(i, e,   j, t, meth, body) {
    meth = ""; body = 0
    for (j = i; j <= e; j++) {
        t = T[j]
        if (t == "-X" || t == "--method") { if (j + 1 <= e) meth = toupper(T[j + 1]); j++; continue }
        if (t ~ /^(-X|--method=)/) { meth = toupper(substr(t, index(t, "=") ? index(t, "=") + 1 : 3)); continue }
        if (t == "-f" || t == "-F" || t == "--field" || t == "--raw-field" || t == "--input") { body = 1; j++; continue }
        if (t ~ /^(--field=|--raw-field=|--input=)/) { body = 1; continue }
        if (t ~ /^-[fF]./) { body = 1; continue }        # `-ftitle=x`, one token
    }
    if (meth != "") return meth
    return body ? "POST" : "GET"
}

# `gh api` is the only write-capable subcommand that takes --hostname, so the
# host is otherwise fixed at github.com. An absolute endpoint carries a host of
# its own and reaches the same place.
function gh_api_host(i, e,   j, t) {
    for (j = i; j <= e; j++) {
        t = T[j]
        if (t == "--hostname") { if (j + 1 <= e) return resolve(T[j + 1], j + 1); return BAD }
        if (t ~ /^--hostname=/) return resolve(substr(t, 12), j)
    }
    return ""
}

function host_of_url(u,   s) {
    s = u
    if (!(s ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\//)) return ""
    sub(/^[A-Za-z][A-Za-z0-9+.-]*:\/\//, "", s)
    sub(/^[^\/@]*@/, "", s)
    sub(/[\/:].*$/, "", s)
    return tolower(s)
}

function gh_api_endpoint(i, e,   j, t) {
    for (j = i; j <= e; j++) {
        t = T[j]
        if (t == "-X" || t == "--method" || t == "-f" || t == "-F" || t == "--field" ||
            t == "--raw-field" || t == "--input" || t == "-H" || t == "--header" ||
            t == "-q" || t == "--jq" || t == "-t" || t == "--template" ||
            t == "--hostname" || t == "--cache" || t == "-p" || t == "--preview") { j++; continue }
        if (t ~ /^-/) continue
        return resolve(t, j)
    }
    return ""
}

function handle_gh(i, e,   sub_, act, j, t, r, meth, ep, host) {
    sub_ = (i + 1 <= e) ? T[i + 1] : ""
    act = (i + 2 <= e) ? T[i + 2] : ""
    if (sub_ == "api") {
        meth = gh_api_method(i + 2, e)
        # A GET reads, whichever repository it names, so the endpoint does not
        # have to resolve. Requiring it turned 66 `gh api repos/$r` survey loops
        # into dialogs.
        if (meth == "GET") return
        host = gh_api_host(i + 2, e)
        if (host == BAD) { fail("gh api " meth ": --hostname uses a shell variable that cannot be resolved"); return }
        ep = gh_api_endpoint(i + 2, e)
        if (ep == BAD) { fail("gh api " meth ": endpoint uses a shell variable that cannot be resolved"); return }
        if (host == "") host = host_of_url(ep)
        if (ep ~ /(^|\/)graphql$/) { fail("gh api graphql: the query may write and names no repository"); return }
        if (ep ~ /\{owner\}|\{repo\}/) {
            # The placeholders are filled from the repository of the working
            # directory, which lives on whatever host its remote names -- not
            # on the one --hostname points at.
            if (host != "") {
                fail("gh api " meth " " ep ": the request goes to " host ", which need not be the host of the working directory")
                return
            }
            if (eff_cwd == BAD) { fail("gh api " meth ": working directory uses a shell variable that cannot be resolved"); return }
            path_fact(eff_cwd == "" ? ENVIRON["GUARD_CWD"] : eff_cwd, "-", "gh api " meth " " ep)
            return
        }
        if (match(ep, /(^|\/)repos\/[^\/{}]+\/[^\/{}]+/)) {
            t = substr(ep, RSTART, RLENGTH)
            sub(/^\/?repos\//, "", t)
            if (parse_repo(t)) {
                repo_fact(host != "" ? tolower(host) : R_HOST, R_NWO, "gh api " meth " " ep)
                return
            }
        }
        fail("gh api " meth " " ep ": the endpoint names no repository")
        return
    }
    if (sub_ == "" || sub_ ~ /^-/) return
    if (index(LOCAL, " " sub_ " ") > 0) return
    if (act == "" || act ~ /^-/) return      # `gh pr`, `gh pr --help`: prints help
    if ((sub_ in READ) && index(READ[sub_], " " act " ") > 0) return
    if (sub_ == "repo" && act == "create") { fail("gh repo create: creates a new repository"); return }
    # `gh issue transfer <number|url> <destination>`: the repository that gains
    # the issue is the last positional, and -R names the one it leaves.
    if (sub_ == "issue" && act == "transfer") {
        t = ""
        for (j = i + 3; j <= e; j++) {
            if (T[j] == "-R" || T[j] == "--repo") { j++; continue }   # its value is the source
            if (T[j] ~ /^-/) continue
            if (is_url(T[j]) || T[j] ~ /^[^\/ ]+\/[^\/ ]+$/) t = resolve(T[j], j)
        }
        if (t == BAD || t == "") { fail("gh issue transfer: the guard could not read the destination repository"); return }
        if (parse_repo(t)) repo_fact(R_HOST, R_NWO, "gh issue transfer -> " t)
        else { fail("gh issue transfer: cannot read a repository out of " t); return }
    }

    r = gh_flag_repo(i + 2, e)
    if (r == BAD) { fail("gh " sub_ " " act ": -R value uses a shell variable that cannot be resolved"); return }
    if (r == "") {
        r = gh_positional_url(i + 3, e)
        if (r == BAD) { fail("gh " sub_ " " act ": URL argument uses a shell variable that cannot be resolved"); return }
    }
    if (r == "" && sub_ == "repo") {                      # `gh repo fork owner/name`
        for (j = i + 3; j <= e; j++) {
            if (T[j] ~ /^-/) continue
            if (T[j] ~ /^[^\/ ]+\/[^\/ ]+$/) { r = resolve(T[j], j); break }
        }
        if (r == BAD) { fail("gh repo " act ": argument uses a shell variable that cannot be resolved"); return }
    }
    if (r == "" && gh_repo_env != "") r = gh_repo_env
    if (r == BAD) { fail("gh " sub_ " " act ": GH_REPO cannot be resolved"); return }
    if (r != "") {
        if (parse_repo(r)) repo_fact(R_HOST, R_NWO, "gh " sub_ " " act " -> " r)
        else fail("gh " sub_ " " act ": cannot read a repository out of " r)
        return
    }
    if (eff_cwd == BAD) { fail("gh " sub_ " " act ": working directory uses a shell variable that cannot be resolved"); return }
    path_fact(eff_cwd == "" ? ENVIRON["GUARD_CWD"] : eff_cwd, "-", "gh " sub_ " " act)
}

function dispatch(i, e,   head) {
    head = basename(T[i])
    if (head == "cd") {
        eff_cwd = (i + 1 <= e) ? join_path(eff_cwd, resolve(T[i + 1], i + 1)) : BAD
    } else if (head == "pushd" || head == "popd") {
        eff_cwd = BAD
    } else if (head == "git") {
        reached = 1; handle_git(i, e)
    } else if (head == "gh") {
        reached = 1; handle_gh(i, e)
    } else if (head == "npm" && i + 1 <= e && T[i + 1] == "publish") {
        reached = 1
        fail("npm publish: the target is a registry, not a repository")
    }
}

# Text the tokenizer cannot reach as commands: hand it back for a second pass
# rather than pattern-matching it, so that a read-only `$(gh pr view ...)` is
# not mistaken for a write. `hpos` is the head of the command, or 0 when the
# range holds nothing but assignments.
function scan_hidden(from, to, hpos,   j, t, head) {
    head = (hpos > 0) ? basename(T[hpos]) : ""
    for (j = from; j <= to; j++) {
        t = T[j]
        if ((t ~ /\$\(/ || index(t, "`") > 0) && looks_outbound(t))
            nest(inner_of(t), "a command substitution")
        else if (hpos > 0 && j > hpos && runs_a_string(head) && looks_outbound(t))
            nest(t, head " runs this")
        # A remote shell runs somewhere this machine knows nothing about,
        # so the local working directory says nothing about the target.
        else if (hpos > 0 && j > hpos && head == "ssh" && looks_outbound(t))
            fail("ssh runs an outbound command on another host: " t)
    }
}

function walk(   i, e, j, head, astart, subdepth) {
    eff_cwd = ""
    i = 1
    subdepth = 0
    while (i <= ntok) {
        # `(cd <notes> && git push) && git push`: the cd inside the parentheses
        # dies with the subshell, so the second push runs where the line began.
        if (TOP[i] && T[i] == "(") { SUBSH[++subdepth] = eff_cwd; i++; continue }
        if (TOP[i] && T[i] == ")") {
            if (subdepth > 0) eff_cwd = SUBSH[subdepth--]
            i++; continue
        }
        if (TOP[i] || !HEAD[i]) { i++; continue }
        # `PR_URL=$(gh pr create ...)` runs the substitution whether or not a
        # command follows it, so the scan has to start before the assignments
        # rather than after the loop that steps over them.
        astart = i
        while (i <= ntok && !TOP[i] &&
               (T[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || is_keyword(T[i]))) i++
        if (i > ntok || TOP[i]) {
            scan_hidden(astart, (i > ntok ? ntok : i - 1), 0)
            continue
        }
        e = argv_end(i)
        head = basename(T[i])
        scan_hidden(astart, e, i)
        # `sudo git push`, `timeout 30 gh pr merge`: the real command sits further
        # along the same argument list.
        if (fronts_a_command(head)) {
            for (j = i + 1; j <= e; j++)
                if (basename(T[j]) ~ /^(git|gh|npm|cd)$/) { i = j; head = basename(T[j]); break }
        }
        dispatch(i, e)
        i = e + 1
    }
}

# ------------------------------------------------------------------ entry
{ L[++nline] = $0 }

END {
    BAD = sprintf("%c", 1)

    # Listing the writes let every verb the table had not heard of through, and
    # `gh` gains verbs faster than this file is edited. The reads are the small,
    # slow-moving half, so they are what gets named: anything else is treated as
    # a write and has to name a repository the guard accepts.
    READ["pr"]       = " list view diff checks status checkout "
    READ["issue"]    = " list view status "
    READ["release"]  = " list view download verify verify-asset "
    READ["repo"]     = " list view clone gitignore license read-dir read-file "
    READ["workflow"] = " list view "
    READ["run"]      = " list view watch download "
    READ["secret"]   = " list "
    READ["variable"] = " list get "
    READ["gist"]     = " list view clone "
    READ["label"]    = " list "
    READ["cache"]    = " list "
    READ["project"]  = " list view field-list item-list "
    READ["ruleset"]  = " list view check "

    # Whole subcommands that never write to a repository. `api` has its own path.
    LOCAL = " api search auth config alias extension completion help status browse version "

    cmd = strip_heredocs()
    if (HDBODY != "") nest(HDBODY, "a heredoc handed to a shell")
    tokenize(cmd)
    scan_assignments()
    has_control = detect_control()

    # Variables that move the target out from under every other rule. Seeing the
    # name anywhere -- even inside quotes or after `export` -- is enough to stop.
    gh_repo_env = ""
    if (cmd ~ /GH_REPO=/) {
        gh_repo_env = lookup("GH_REPO", ntok + 1)
        if (gh_repo_env == BAD) gh_repo_env = BAD
    }
    if (cmd ~ /(GIT_DIR|GIT_WORK_TREE|GH_HOST)=/) redirect_env = 1

    walk()

    # Branching only matters when the target came from following `cd`. An
    # explicit -R or URL says which repository it is whichever branch ran.
    if (found_path && has_control)
        print "ASK\tthe command branches or loops, so the working directory cannot be followed statically"
    if (found && redirect_env)
        print "ASK\tGIT_DIR, GIT_WORK_TREE or GH_HOST is set, which moves the target"
    if (found_path && remote_rewritten)
        print "ASK\tthe command changes a remote before it pushes, so the configuration the guard read is not the one git will use"

    # Nothing here reached a handler, yet the text still reads as outbound:
    # an unknown wrapper, a string handed to another shell, something the
    # tokenizer walked past. The set of those cannot be finished by listing
    # them, so silence has to mean ask rather than mean nothing was there.
    if (!reached && looks_outbound(cmd))
        print "ASK\tthe guard could not find the outbound command in this line"

    # Last line, always. A truncated or empty analyser still exits 0 with no
    # output, which the caller would otherwise read as "nothing outbound here".
    print "END"
}
