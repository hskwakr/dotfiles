if type brew &>/dev/null; then
    if ! [[ "$FPATH" =~ "$(brew --prefix)/share/zsh/site-functions" ]]; then
        FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
        autoload -Uz compinit
        compinit
    fi
fi

if type eza &>/dev/null; then
    alias ls="eza"
    alias ll="eza -l"
    alias la="eza -la"
    alias lt="eza --tree"
    alias lg="eza -l --git"

    alias lsa="eza -a"
    alias lla="eza -la"
    alias llt="eza -T"
    alias llm="eza -l --sort=modified"
    alias lld="eza -ld */"
fi
