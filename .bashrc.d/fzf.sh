export FZF_DEFAULT_OPTS="
--layout=reverse
--info=inline
--height=80%
--border
--padding=1
--multi
--bind '?:toggle-preview'
--bind 'ctrl-a:select-all'
"

export FZF_CTRL_T_OPTS="
--preview '([[ -f {} ]] && (cat {} | less)) || ([[ -d {} ]] && (tree -L 3 -C {} | less)) || echo {} 2> /dev/null | head -200'
"

export FZF_CTRL_R_OPTS="
--tiebreak=index
--preview 'echo {} | fold -w 100 -s | head -n 10'
--preview-window up:3:wrap
"

export FZF_ALT_C_OPTS="
--preview 'tree -L 3 -C {}'
"

function fman() {
    man -k . | fzf -q "$1" --prompt='man> '  --preview $'echo {} | tr -d \'()\' | awk \'{printf "%s ", $2} {print $1}\' | xargs -r man' | tr -d '()' | awk '{printf "%s ", $2} {print $1}' | xargs -r man
}

# fbr - checkout git branch (including remote branches), sorted by most recent commit, limit 30 last branches
fbr() {
  git fetch --all
  local branches branch
  branches=$(git for-each-ref --count=30 --sort=-committerdate refs/{heads,remotes}/ --format="%(refname:short)") &&
  branch=$(echo "$branches" |
           fzf-tmux -w 80 +m) &&
  if [[ "$branch" =~ ^[^/]+/[^/]+ ]]; then
    git switch --track "$branch"
  else
    git checkout $(echo "$branch" | sed "s/.* //")
  fi
}

# fbr-delete - delete git local branch with fzf
fbr-delete() {
  git branch | \
  fzf --preview 'branch=$(echo {} | sed "s/.* //"); git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" $branch -10' \
      --preview-window=right:70% | \
  xargs git branch -d
}

# Select docker container to remove 
function drm() {
  docker ps -a | sed 1d | fzf -q "$1" --no-sort -m --tac | awk '{ print $1 }' | xargs -r docker rm
}

# Select a docker image or images to remove
function drmi() {
  docker images | sed 1d | fzf -q "$1" --no-sort -m --tac | awk '{ print $3 }' | xargs -r docker rmi
}

# fdl: Interactively select a running Docker container using fzf,
# and tail its logs in follow mode.
fdl() {
  # Note: This function is intended for interactive shells (.bashrc).

  # Check that required commands exist.
  for cmd in docker fzf; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf "fdl: Error: Required command '%s' is not installed.\n" "$cmd" >&2
      return 1
    fi
  done

  # Declare local variables to avoid polluting the global namespace.
  local container_selection container_id

  # Get the list of running containers in the format:
  # "CONTAINER_ID: IMAGE (NAME)"
  # Pipe the output to fzf for interactive selection.
  container_selection=$(
    docker ps --format '{{.ID}}: {{.Image}} ({{.Names}})' 2>/dev/null |
      fzf --prompt="Select container > " \
          --ansi \
          --preview='docker logs --tail 100 {1}' 2>/dev/null
  )

  # If nothing was selected (e.g., user pressed ESC), exit early.
  if [[ -z "$container_selection" ]]; then
    printf "fdl: No container selected.\n" >&2
    return 1
  fi

  # Extract the container ID from the selected line.
  # The expected format is "CONTAINER_ID: IMAGE (NAME)".
  container_id=$(printf "%s" "$container_selection" | cut -d':' -f1)

  # Provide user feedback.
  printf "fdl: Tailing logs for container %s\n" "$container_id"

  # Tail the logs of the selected container in follow mode.
  docker logs -f "$container_id"
}
