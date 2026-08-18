#!/usr/bin/env bash
set -Eeuo pipefail

# --- Config ---
NERD_FONT_NAME="IBMPlexMono"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${NERD_FONT_NAME}.zip"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES_FILE="${SCRIPT_DIR}/packages.txt"
TPM_REPO="https://github.com/tmux-plugins/tpm.git"
NVIM_DIR="$HOME/.local/opt/nvim"
NVIM_TARBALL_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
WIN32YANK_URL="https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip"

log() { echo -e "\e[1;32m[setup]\e[0m $*"; }
action() { echo -e "\e[1;30;43m ACTION NEEDED \e[0m $*"; }

# Surface exactly where/why the script died instead of failing silently
# (set -e just stops execution with no indication of what broke).
on_error() {
	echo -e "\e[1;31m[setup] FAILED\e[0m (exit $1) at line $2: $3" >&2
}
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

is_wsl() {
	grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

resolve_bat_bin() {
	if command -v bat &>/dev/null; then
		echo bat
	elif command -v batcat &>/dev/null; then
		echo batcat
	fi
}

enable_apt_repos() {
	log "Enabling third-party apt repositories"

	sudo install -m 0755 -d /etc/apt/keyrings

	# eza: not available (or too old) on stock Ubuntu, use the official repo.
	if [[ ! -f /etc/apt/keyrings/gierens.gpg ]]; then
		wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
			| sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
		echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
			| sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
		sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
		log "eza apt repo enabled"
	else
		log "eza apt repo already enabled, skipping"
	fi

	sudo apt-get update
}

init_submodules() {
	log "Initializing git submodules"
	git -C "$SCRIPT_DIR" submodule update --init --recursive
}

install_packages() {
	log "Installing packages from ${PACKAGES_FILE}"
	if [[ ! -f "$PACKAGES_FILE" ]]; then
		log "No packages.txt found, skipping"
		return
	fi
	local packages=()
	readarray -t packages < <(grep -vE '^\s*(#|$)' "$PACKAGES_FILE" | sed 's/\s*#.*//')
	sudo apt-get install -y "${packages[@]}"
}

install_starship() {
	if command -v starship &>/dev/null; then
		log "starship already installed, skipping"
		return
	fi
	log "Installing starship"
	curl -sS https://starship.rs/install.sh | sh -s -- --yes
}

install_zoxide() {
	if command -v zoxide &>/dev/null; then
		log "zoxide already installed, skipping"
		return
	fi
	log "Installing zoxide"
	curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
}

install_neovim() {
	log "Installing Neovim"
	mkdir -p "$HOME/.local/bin"

	if [[ -x "$NVIM_DIR/bin/nvim" ]]; then
		log "Neovim already installed at ${NVIM_DIR}, skipping (remove that dir to update)"
	else
		local tmp_tar
		tmp_tar="$(mktemp --suffix=.tar.gz)"
		wget -q -O "$tmp_tar" "$NVIM_TARBALL_URL"
		rm -rf "$NVIM_DIR"
		mkdir -p "$NVIM_DIR"
		tar -xzf "$tmp_tar" --strip-components=1 -C "$NVIM_DIR"
		rm -f "$tmp_tar"
	fi

	ln -sf "$NVIM_DIR/bin/nvim" "$HOME/.local/bin/nvim"
	log "Neovim installed"
}

install_lazygit() {
	if command -v lazygit &>/dev/null; then
		log "lazygit already installed, skipping"
		return
	fi
	log "Installing lazygit"

	local tag_name version tmp_tar
	tag_name="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r '.tag_name')"
	version="${tag_name#v}"
	tmp_tar="$(mktemp --suffix=.tar.gz)"
	wget -q -O "$tmp_tar" "https://github.com/jesseduffield/lazygit/releases/download/${tag_name}/lazygit_${version}_linux_x86_64.tar.gz"
	mkdir -p "$HOME/.local/bin"
	tar -xzf "$tmp_tar" -C "$HOME/.local/bin" lazygit
	rm -f "$tmp_tar"
	log "lazygit ${version} installed"
}

install_delta() {
	if command -v delta &>/dev/null; then
		log "git-delta already installed, skipping"
		return
	fi
	log "Installing git-delta"

	local tag_name version arch tmp_deb
	tag_name="$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest | jq -r '.tag_name')"
	version="${tag_name#v}"
	arch="$(dpkg --print-architecture)"
	tmp_deb="$(mktemp --suffix=.deb)"
	wget -q -O "$tmp_deb" "https://github.com/dandavison/delta/releases/download/${tag_name}/git-delta_${version}_${arch}.deb"
	sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y
	rm -f "$tmp_deb"
	log "git-delta ${version} installed"
}

install_bat() {
	if command -v bat &>/dev/null; then
		log "bat already installed, skipping"
		return
	fi
	log "Installing bat"

	local tag_name version arch tmp_deb
	tag_name="$(curl -fsSL https://api.github.com/repos/sharkdp/bat/releases/latest | jq -r '.tag_name')"
	version="${tag_name#v}"
	arch="$(dpkg --print-architecture)"
	tmp_deb="$(mktemp --suffix=.deb)"
	wget -q -O "$tmp_deb" "https://github.com/sharkdp/bat/releases/download/${tag_name}/bat_${version}_${arch}.deb"
	sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y
	rm -f "$tmp_deb"
	log "bat ${version} installed"
}

install_fzf() {
	local tag_name version arch installed tmp_deb
	tag_name="$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest | jq -r '.tag_name')"
	version="${tag_name#v}"
	installed="$(dpkg-query -W -f='${Version}' fzf 2>/dev/null || true)"
	if [[ "$installed" == "$version" ]]; then
		log "fzf already installed, skipping"
		return
	fi
	log "Installing fzf"

	arch="$(dpkg --print-architecture)"
	tmp_deb="$(mktemp --suffix=.deb)"
	wget -q -O "$tmp_deb" "https://github.com/junegunn/fzf/releases/download/${tag_name}/fzf_${version}_${arch}.deb"
	sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y
	rm -f "$tmp_deb"
	log "fzf ${version} installed"
}

install_fastfetch() {
	if command -v fastfetch &>/dev/null; then
		log "fastfetch already installed, skipping"
		return
	fi
	log "Installing fastfetch"

	local tag_name arch tmp_deb
	tag_name="$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | jq -r '.tag_name')"
	arch="$(dpkg --print-architecture)"
	case "$arch" in
		amd64) arch=amd64 ;;
		arm64) arch=aarch64 ;;
		*)
			log "Unsupported architecture ${arch} for fastfetch, skipping"
			return
			;;
	esac
	tmp_deb="$(mktemp --suffix=.deb)"
	wget -q -O "$tmp_deb" "https://github.com/fastfetch-cli/fastfetch/releases/download/${tag_name}/fastfetch-linux-${arch}.deb"
	sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y
	rm -f "$tmp_deb"
	log "fastfetch ${tag_name} installed"
}

install_onefetch() {
	if command -v onefetch &>/dev/null; then
		log "onefetch already installed, skipping"
		return
	fi
	log "Installing onefetch"

	local tag_name tmp_deb
	tag_name="$(curl -fsSL https://api.github.com/repos/o2sh/onefetch/releases/latest | jq -r '.tag_name')"
	tmp_deb="$(mktemp --suffix=.deb)"
	wget -q -O "$tmp_deb" "https://github.com/o2sh/onefetch/releases/download/${tag_name}/onefetch_amd64.deb"
	sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y
	rm -f "$tmp_deb"
	log "onefetch ${tag_name} installed"
}

install_claude_code() {
	if command -v claude &>/dev/null; then
		log "Claude Code already installed, skipping (it self-updates)"
		return
	fi
	log "Installing Claude Code"
	curl -fsSL https://claude.ai/install.sh | bash
}

install_win32yank() {
	if ! is_wsl; then
		return
	fi
	if command -v win32yank.exe &>/dev/null; then
		log "win32yank.exe already installed, skipping"
		return
	fi
	log "Installing win32yank.exe (WSL clipboard bridge for Neovim's 'unnamedplus')"

	mkdir -p "$HOME/.local/bin"
	local tmp_zip
	tmp_zip="$(mktemp --suffix=.zip)"
	wget -q -O "$tmp_zip" "$WIN32YANK_URL"
	unzip -qo "$tmp_zip" win32yank.exe -d "$HOME/.local/bin"
	rm -f "$tmp_zip"
	chmod +x "$HOME/.local/bin/win32yank.exe"
	log "win32yank.exe installed, Neovim will auto-detect it"
}

setup_windows_fonts() {
	if ! is_wsl; then
		log "Not running under WSL, skipping Windows font download"
		return
	fi
	if ! command -v powershell.exe &>/dev/null; then
		log "powershell.exe not found (WSL interop disabled?), skipping Windows font download"
		return
	fi

	log "Downloading ${NERD_FONT_NAME} Nerd Font for Windows Terminal"

	local win_profile win_downloads target_zip
	win_profile="$(powershell.exe -NoProfile -Command '[Environment]::GetFolderPath("UserProfile")' 2>/dev/null | tr -d '\r')"
	win_downloads="$(wslpath -u "${win_profile}")/Downloads"

	if [[ ! -d "$win_downloads" ]]; then
		log "Windows Downloads folder not found at ${win_downloads}, skipping"
		return
	fi

	target_zip="${win_downloads}/${NERD_FONT_NAME}.zip"
	if [[ -f "$target_zip" ]]; then
		log "${target_zip} already present, skipping download"
	else
		wget -q -O "$target_zip" "$NERD_FONT_URL"
	fi

	log "Saved to ${target_zip}."
	action "(on Windows): extract that zip, select all the .ttf files, right-click > Install."
	action "Then set Windows Terminal's font to \"BlexMono Nerd Font\"."
}

setup_dotfiles() {
	log "Setting up dotfiles"

	local bash_config_dir="$HOME/.config/bash"
	mkdir -p "$bash_config_dir"
	ln -sf "${SCRIPT_DIR}/dotfiles/starship.sh" "$bash_config_dir/starship.sh"

	local bash_source_line="source \"$bash_config_dir/starship.sh\""
	if ! grep -qF "$bash_config_dir/starship.sh" "$HOME/.bashrc" 2>/dev/null; then
		echo "$bash_source_line" >> "$HOME/.bashrc"
		log "Added starship source line to .bashrc"
	fi

	local zsh_config_dir="$HOME/.config/zsh"
	mkdir -p "$zsh_config_dir"
	ln -sf "${SCRIPT_DIR}/dotfiles/starship.zsh" "$zsh_config_dir/starship.zsh"
	ln -sf "${SCRIPT_DIR}/dotfiles/aliases.zsh" "$zsh_config_dir/aliases.zsh"

	ln -sf "${SCRIPT_DIR}/dotfiles/zshenv" "$HOME/.zshenv"

	local zsh_source_line="source \"$zsh_config_dir/starship.zsh\""
	if ! grep -qF "$zsh_config_dir/starship.zsh" "$HOME/.zshrc" 2>/dev/null; then
		echo "$zsh_source_line" >> "$HOME/.zshrc"
		log "Added starship source line to .zshrc"
	fi

	local aliases_source_line="source \"$zsh_config_dir/aliases.zsh\""
	if ! grep -qF "$zsh_config_dir/aliases.zsh" "$HOME/.zshrc" 2>/dev/null; then
		echo "$aliases_source_line" >> "$HOME/.zshrc"
		log "Added aliases source line to .zshrc"
	fi

	ln -sf "${SCRIPT_DIR}/dotfiles/completion.zsh" "$zsh_config_dir/completion.zsh"

	local completion_source_line="source \"$zsh_config_dir/completion.zsh\""
	if ! grep -qF "$zsh_config_dir/completion.zsh" "$HOME/.zshrc" 2>/dev/null; then
		echo "$completion_source_line" >> "$HOME/.zshrc"
		log "Added completion source line to .zshrc"
	fi

	ln -sf "${SCRIPT_DIR}/dotfiles/fzf-catppuccin.sh" "$zsh_config_dir/fzf-catppuccin.sh"

	local fzf_theme_source_line="source \"$zsh_config_dir/fzf-catppuccin.sh\""
	if ! grep -qF "$zsh_config_dir/fzf-catppuccin.sh" "$HOME/.zshrc" 2>/dev/null; then
		echo "$fzf_theme_source_line" >> "$HOME/.zshrc"
		log "Added fzf Catppuccin theme source line to .zshrc"
	fi

	ln -sf "${SCRIPT_DIR}/dotfiles/welcome.zsh" "$zsh_config_dir/welcome.zsh"

	local welcome_source_line="source \"$zsh_config_dir/welcome.zsh\""
	if ! grep -qF "$zsh_config_dir/welcome.zsh" "$HOME/.zshrc" 2>/dev/null; then
		echo "$welcome_source_line" >> "$HOME/.zshrc"
		log "Added welcome screen source line to .zshrc"
	fi

	mkdir -p "$HOME/.config"
	ln -sf "${SCRIPT_DIR}/dotfiles/starship.toml" "$HOME/.config/starship.toml"

	local tmux_config_dir="$HOME/.config/tmux"
	mkdir -p "$tmux_config_dir"
	ln -sf "${SCRIPT_DIR}/dotfiles/tmux/tmux.conf" "${tmux_config_dir}/tmux.conf"

	ln -sfT "${SCRIPT_DIR}/dotfiles/nvim" "$HOME/.config/nvim"

	local lazygit_config_dir="$HOME/.config/lazygit"
	mkdir -p "$lazygit_config_dir"
	ln -sf "${SCRIPT_DIR}/dotfiles/lazygit/config.yml" "${lazygit_config_dir}/config.yml"

	local bat_config_dir="$HOME/.config/bat"
	mkdir -p "$bat_config_dir"
	ln -sf "${SCRIPT_DIR}/dotfiles/bat/config" "${bat_config_dir}/config"
	ln -sfT "${SCRIPT_DIR}/dotfiles/bat/themes" "${bat_config_dir}/themes"

	local git_config_dir="$HOME/.config/git"
	mkdir -p "$git_config_dir"
	ln -sf "${SCRIPT_DIR}/dotfiles/delta/catppuccin.gitconfig" "${git_config_dir}/catppuccin.gitconfig"
	ln -sf "${SCRIPT_DIR}/dotfiles/git/aliases.gitconfig" "${git_config_dir}/aliases.gitconfig"
	ln -sf "${SCRIPT_DIR}/dotfiles/git/config.gitconfig" "${git_config_dir}/config.gitconfig"

	local btop_config_dir="$HOME/.config/btop"
	mkdir -p "$btop_config_dir"
	ln -sf "${SCRIPT_DIR}/dotfiles/btop/btop.conf" "${btop_config_dir}/btop.conf"
	ln -sfT "${SCRIPT_DIR}/dotfiles/btop/themes" "${btop_config_dir}/themes"
}

build_bat_cache() {
	local bat_bin
	bat_bin="$(resolve_bat_bin)"
	if [[ -z "$bat_bin" ]]; then
		log "bat/batcat not found, skipping bat theme cache build"
		return
	fi

	log "Rebuilding bat theme cache"
	"$bat_bin" cache --build
}

build_tldr_cache() {
	if ! command -v tldr &>/dev/null; then
		log "tldr not found, skipping tldr cache update"
		return
	fi

	log "Updating tldr pages cache"
}

install_tmux_plugins() {
	log "Installing tmux plugin manager (tpm)"

	local tpm_dir="$HOME/.config/tmux/plugins/tpm"
	if [[ -d "$tpm_dir" ]]; then
		log "tpm already installed, skipping clone"
	else
		git clone -q "$TPM_REPO" "$tpm_dir"
	fi

	log "Installing tmux plugins declared in tmux.conf"
	"$tpm_dir/bin/install_plugins"
}

set_default_shell() {
	log "Setting zsh as default shell"

	local zsh_path current_shell
	zsh_path="$(command -v zsh)"
	# Check the shell registered in /etc/passwd, not $SHELL: $SHELL just
	# reflects whatever shell this script happens to be running under
	# (e.g. if zsh was launched manually to try it out), which can differ
	# from what chsh last actually persisted.
	current_shell="$(getent passwd "$USER" | cut -d: -f7)"

	if [[ "$current_shell" == "$zsh_path" ]]; then
		log "zsh is already the default shell, skipping"
		return
	fi

	if ! grep -qF "$zsh_path" /etc/shells 2>/dev/null; then
		log "Registering ${zsh_path} in /etc/shells"
		echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
	fi

	# usermod (not chsh) writes /etc/passwd directly via sudo, instead of
	# going through PAM's interactive chsh auth prompt, which has proven
	# flaky/silently-failing in some environments (e.g. WSL).
	sudo usermod --shell "$zsh_path" "$USER"
	log "Default shell set to zsh (effective on next login)"
}

configure_docker() {
	log "Configuring Docker"

	if command -v docker &>/dev/null && docker info &>/dev/null; then
		log "docker already available and working (Docker Desktop WSL integration?), skipping install"
		return
	fi

	log "No working docker found, installing Docker Engine from the official apt repo"

	local keyring="/etc/apt/keyrings/docker.asc"
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$keyring"
	sudo chmod a+r "$keyring"

	local codename
	codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
	echo "deb [arch=$(dpkg --print-architecture) signed-by=${keyring}] https://download.docker.com/linux/ubuntu ${codename} stable" \
		| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

	if ! getent group docker &>/dev/null; then
		log "docker group not found, skipping group membership"
	elif id -nG "$USER" | grep -qw docker; then
		log "${USER} already in docker group, skipping"
	else
		sudo usermod -aG docker "$USER"
		log "Added ${USER} to docker group (log out and back in, or run 'newgrp docker', for this to take effect)"
	fi

	if [[ -d /run/systemd/system ]]; then
		sudo systemctl enable --now docker.service
	else
		log "systemd not active in this WSL instance, dockerd won't start automatically."
		log "Add to /etc/wsl.conf: '[boot]' / 'systemd=true', then run 'wsl --shutdown' from Windows and reopen this distro."
	fi
}

configure_git() {
	log "Configuring git"

	# All settings (editor, delta, catppuccin theme, aliases, ...) live in
	# dotfiles/git/config.gitconfig, symlinked into ~/.config/git by
	# setup_dotfiles. Only this single include is set imperatively here,
	# since include.path replaces rather than appends on repeated calls.
	git config --global include.path "$HOME/.config/git/config.gitconfig"
}

main() {
	enable_apt_repos
	install_packages
	install_starship
	install_zoxide
	install_neovim
	install_lazygit
	install_bat
	install_delta
<<<<<<< HEAD
	install_fastfetch
	install_onefetch
||||||| parent of 54b8470 (Install fzf from GitHub releases instead of apt)
=======
	install_fzf
>>>>>>> 54b8470 (Install fzf from GitHub releases instead of apt)
	install_claude_code
	install_win32yank
	setup_windows_fonts
	init_submodules
	setup_dotfiles
	build_bat_cache
	build_tldr_cache
	install_tmux_plugins
	configure_docker
	configure_git
	set_default_shell
	log "Setup done !"
}

main "$@"
