# Check if rokit is installed
# ~/.rokit/env prepends ~/.rokit/bin to PATH (idempotent, safe to source twice)
if [ -d "$HOME/.rokit" ] && [ -f "$HOME/.rokit/env" ]; then
    . "$HOME/.rokit/env"
fi
