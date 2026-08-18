eval "$(zoxide init zsh --cmd cd)"
eval "$(fzf --zsh)"
eval "$(direnv hook zsh)"

alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -l --group-directories-first --icons=auto'
alias la='eza -la --group-directories-first --icons=auto'
alias lt='eza --tree --level 1 --group-directories-first --icons=auto'

# Debian/Ubuntu ship bat and fd-find under the names batcat/fdfind to avoid
# clashing with unrelated packages already using "bat"/"find".
if command -v bat &>/dev/null; then
	alias cat='bat'
elif command -v batcat &>/dev/null; then
	alias cat='batcat'
	alias bat='batcat'
fi

if command -v fd &>/dev/null; then
	alias find='fd'
elif command -v fdfind &>/dev/null; then
	alias find='fdfind'
	alias fd='fdfind'
fi

alias vim='nvim'
alias top='btop'
alias lg='lazygit'
