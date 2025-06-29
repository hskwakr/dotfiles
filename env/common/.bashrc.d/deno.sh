# Check if deno is installed
if [ -d "$HOME/.deno" ] && [ -f "$HOME/.deno/env" ]; then
    . ~/.deno/env
    # Only source completion file if it exists
    if [ -f "$HOME/.local/share/bash-completion/completions/deno.bash" ]; then
        source ~/.local/share/bash-completion/completions/deno.bash
    fi
fi
