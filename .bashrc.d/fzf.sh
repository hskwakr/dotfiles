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