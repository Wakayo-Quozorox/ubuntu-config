# onefetch's repo stats when the cwd is inside a git repository (every shell:
# repo state is worth re-checking each time). Otherwise fastfetch's system
# banner, but only once per WSL session: /tmp is tmpfs and gets wiped on
# `wsl --shutdown`/reboot, so this flag naturally resets on a real restart
# instead of firing again on every new terminal tab or tmux pane.
if command -v onefetch &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
	onefetch
elif command -v fastfetch &>/dev/null && [[ ! -f /tmp/.welcome_shown ]]; then
	fastfetch
	touch /tmp/.welcome_shown
fi
