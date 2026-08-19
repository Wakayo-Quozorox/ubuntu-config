# Shown once per interactive shell start: onefetch's repo stats when the cwd
# is inside a git repository, fastfetch's system banner otherwise.
if command -v onefetch &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
	onefetch
elif command -v fastfetch &>/dev/null; then
	fastfetch
fi
