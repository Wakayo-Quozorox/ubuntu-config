# ubuntu-config

Personal tool setup for Ubuntu, primarily targeting **WSL2** (Windows
Subsystem for Linux). Mirrors the tool configuration from my
[Fedora setup](https://github.com/Wakayo-Quozorox/customization-fedora), minus
anything GNOME/desktop-specific that doesn't apply here (accent color,
wallpaper, GNOME keybindings, Flathub, kitty/ghostty — under WSL the terminal
emulator is Windows Terminal, not a Linux GUI app).

## Usage

```sh
git clone --recurse-submodules git@github.com:Wakayo-Quozorox/ubuntu-config.git
cd ubuntu-config
./setup.sh
```

The script is idempotent — safe to re-run after pulling updates.

## What it sets up

- **Shell**: zsh (default shell), zsh-autosuggestions, zsh-syntax-highlighting,
  starship prompt, zoxide, fzf, direnv — bash is also wired up with the
  starship prompt as a fallback.
- **Terminal multiplexer**: tmux, with tpm and the same plugin set as the
  Fedora config (catppuccin theme, resurrect/continuum, vim-tmux-navigator).
- **Editor**: Neovim (kickstart-based config, submodule), installed from the
  official GitHub release tarball since Ubuntu's apt version is normally too
  old for it.
- **Git tooling**: lazygit, git-delta (Catppuccin Mocha theme), same
  `configure_git` global config as the Fedora setup.
- **Claude Code**: installed via the official native installer
  (`curl -fsSL https://claude.ai/install.sh | bash`), no Node.js required; it
  self-updates afterwards.
- **Modern CLI replacements**: ripgrep, fd, bat, eza, btop, tealdeer (`tldr`).
- **Build tools**: make, gcc, clang + clang-format/clang-tidy/clangd, bear.
- **Docker**: uses Docker Desktop's WSL integration if `docker` already works;
  otherwise installs Docker Engine from the official apt repo and enables it
  via systemd if the WSL instance has systemd enabled (see below).
- **WSL-specific extras**:
  - `win32yank.exe` so Neovim's `unnamedplus` clipboard syncs with Windows.
  - Downloads the BlexMono Nerd Font zip straight into your Windows Downloads
    folder (font *installation* itself has to happen on the Windows side —
    extract, select all `.ttf` files, right-click > Install — then set that
    font in Windows Terminal).

## Not included on purpose

- **VS Code**: install it on Windows and use the "WSL" extension to connect
  into this distro (`code .` from a WSL shell then works automatically). No
  need to install VS Code inside WSL itself.
- **kitty / ghostty**: the actual terminal emulator here is Windows Terminal;
  no Linux GUI terminal is installed.

## Notes on Debian/Ubuntu package naming

- `bat`'s binary is named `batcat` (name clash with an unrelated package);
  `fd-find`'s binary is named `fdfind`. `dotfiles/aliases.zsh` detects
  whichever is present and aliases accordingly.
- `eza`, `starship`, `zoxide`, `neovim`, `lazygit`, `git-delta`, `claude` aren't
  available (or are too outdated) via stock apt, so `setup.sh` pulls them
  from their official repo/installer/GitHub releases instead — see the
  `install_*` functions.
- `tldr`'s Debian/Ubuntu apt package name is unreliable across releases; we
  use `tealdeer` instead, which provides the same `tldr` binary.

## Windows Terminal profile

The Ubuntu profile's *Command line* should be exactly:

```
wsl.exe -d Ubuntu --cd ~
```

`--cd ~` is the documented WSL flag for starting in the Linux user's home
directory. Don't append a bare `~` as its own argument without `--cd` —
without it, WSL treats `~` as a command to *run* rather than a directory,
which (still on bash, or if the shell field is otherwise off) fails with
something like `/bin/bash: line 1: /home/<user>: Is a directory`.

If the profile's command line is already correct but the shell still isn't
zsh, check what's actually registered for your user rather than trusting a
running shell's `$SHELL`:

```sh
getent passwd "$USER" | cut -d: -f7
```

`setup.sh`'s `set_default_shell` uses `sudo usermod --shell` (not `chsh`) for
exactly this reason — `chsh`'s interactive PAM prompt has been unreliable
under WSL in practice.

## Enabling systemd in WSL (optional, needed for native Docker)

If you're not using Docker Desktop and want `configure_docker`'s
`systemctl enable --now docker` to actually take effect, add to
`/etc/wsl.conf`:

```ini
[boot]
systemd=true
```

then run `wsl --shutdown` from Windows and reopen the distro.
