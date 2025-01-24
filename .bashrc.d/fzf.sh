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
