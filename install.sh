#!/usr/bin/env bash
#
# Manage dotfile symlinks between this repo and $HOME.
#
#   ./install.sh                full config (workstation: macOS or Linux)
#   ./install.sh --bootstrap    full config, installing missing dependencies
#   ./install.sh --minimal      server profile: vim + bash, zero dependencies
#   ./install.sh --uninstall    remove our symlinks and restore the newest backup
#
# Idempotent: re-running only changes what has drifted. Anything real already
# sitting at a target (regular file or hard link) is archived, never deleted.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="${HOME}/.dotfiles-backup/$(date +%Y%m%d%H%M%S)"
BASHRC_MARKER="# >>> dotfiles server profile >>>"

MODE="full"
BOOTSTRAP="no"

usage() {
  sed -n '3,11p' "${BASH_SOURCE[0]}" | sed 's/^#\s\?//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --bootstrap|-b) BOOTSTRAP="yes" ;;
    --minimal|-m)   MODE="minimal" ;;
    --uninstall|-u) MODE="uninstall" ;;
    --help|-h)      usage 0 ;;
    *) echo "unknown option: $1" >&2; usage 2 >&2 ;;
  esac
  shift
done

# repo-relative source : $HOME-relative target
full_links=(
  "zsh/zshenv:.zshenv"
  "zsh/zprofile:.zprofile"
  "zsh/zshrc:.zshrc"
  "vim/vimrc:.vimrc"
  "vim/plugins.vim:.vim/plugins.vim"
  "tmux/tmux.conf:.config/tmux/tmux.conf"
  "git/gitconfig:.gitconfig"
  "git/ignore:.config/git/ignore"
  "ghostty/config:.config/ghostty/config"
  "bat/config:.config/bat/config"
  "k9s/config.yaml:.config/k9s/config.yaml"
  "k9s/aliases.yaml:.config/k9s/aliases.yaml"
  "k9s/skins/dracula.yaml:.config/k9s/skins/dracula.yaml"
  "terraform/terraformrc:.terraformrc"
  "powerline/config.json:.config/powerline/config.json"
  "claude/settings.json:.claude/settings.json"
  "gh/config.yml:.config/gh/config.yml"
  "opencode/opencode.json:.config/opencode/opencode.json"
  "opencode/tui.json:.config/opencode/tui.json"
  "ssh/config:.ssh/config"
)

# Servers get vim and bash only. No zsh config, no oh-my-zsh, no plugins.
minimal_links=(
  "server/vimrc:.vimrc"
)

#------------------------------------------------------------------------------
# DEPENDENCIES
#------------------------------------------------------------------------------
# Only what the configs in this repo need in order to load without error.
# System packages (zsh, vim, brew formulae) are osx-setup's job, not ours.

clone_if_absent() {
  local dest="$1" url="$2" label="$3"
  if [ -d "${dest}" ]; then
    echo "ok   ${label}"
  else
    echo "inst ${label}"
    git clone --depth=1 --quiet "${url}" "${dest}"
  fi
}

bootstrap_deps() {
  if ! command -v git >/dev/null 2>&1; then
    echo "!! git is required to bootstrap dependencies" >&2
    exit 1
  fi

  clone_if_absent "${HOME}/.oh-my-zsh" \
    "https://github.com/ohmyzsh/ohmyzsh.git" "oh-my-zsh"

  local custom="${HOME}/.oh-my-zsh/custom/plugins"
  clone_if_absent "${custom}/zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
  clone_if_absent "${custom}/zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting"

  # vim-plug, required by vim/plugins.vim
  if [ -f "${HOME}/.vim/autoload/plug.vim" ]; then
    echo "ok   vim-plug"
  elif command -v curl >/dev/null 2>&1; then
    echo "inst vim-plug"
    curl -fsSLo "${HOME}/.vim/autoload/plug.vim" --create-dirs \
      "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
  else
    echo "skip vim-plug (curl not available)"
  fi

  # Neovim config is its own repo; only clone it if nothing is there.
  if [ -e "${HOME}/.config/nvim" ]; then
    echo "ok   nvim config (left as-is)"
  else
    clone_if_absent "${HOME}/.config/nvim" \
      "https://github.com/hansohn/nvim.git" "nvim config"
  fi
}

# Run after linking, so plugins.vim is in place.
bootstrap_vim_plugins() {
  local plugged="${HOME}/.vim/plugged"

  if [ ! -f "${HOME}/.vim/autoload/plug.vim" ] || ! command -v vim >/dev/null 2>&1; then
    return
  fi

  # Already populated -- stay a no-op so re-running changes nothing.
  if [ -d "${plugged}" ] && [ -n "$(ls -A "${plugged}" 2>/dev/null)" ]; then
    echo "ok   vim plugins"
    return
  fi

  echo "inst vim plugins (PlugInstall)"
  vim -es -u "${HOME}/.vimrc" -i NONE -c "PlugInstall! --sync" -c qa >/dev/null 2>&1 || true
}

#------------------------------------------------------------------------------
# LINKING
#------------------------------------------------------------------------------

link_all() {
  local pair rel src dst
  for pair in "$@"; do
    rel="${pair##*:}"
    src="${REPO}/${pair%%:*}"
    dst="${HOME}/${rel}"

    if [ ! -e "${src}" ]; then
      echo "!! missing source: ${src}" >&2
      exit 1
    fi

    # already pointing where it should
    if [ -L "${dst}" ] && [ "$(readlink "${dst}")" = "${src}" ]; then
      echo "ok   ${dst}"
      continue
    fi

    # archive anything real in the way -- regular file or hard link
    if [ -e "${dst}" ] && [ ! -L "${dst}" ]; then
      mkdir -p "$(dirname "${BACKUP}/${rel}")"
      mv "${dst}" "${BACKUP}/${rel}"
      echo "bak  ${dst} -> ${BACKUP}/${rel}"
    fi

    mkdir -p "$(dirname "${dst}")"
    # -n so a stale symlink is replaced rather than followed into a directory
    ln -sfn "${src}" "${dst}"
    echo "link ${dst} -> ${src}"
  done
}

#------------------------------------------------------------------------------
# UNINSTALL
#------------------------------------------------------------------------------
# Removes only symlinks that point into this repo -- never a real file, and
# never a symlink someone else created. Restores the newest backup if one
# covers the file. Bootstrapped dependencies are left alone; they are shared
# with other tools and deleting them is not ours to decide.

newest_backup() {
  local d
  d="$(find "${HOME}/.dotfiles-backup" -maxdepth 1 -mindepth 1 -type d 2>/dev/null \
       | sort | tail -1)"
  [ -n "${d}" ] && printf '%s' "${d}"
}

uninstall_all() {
  local restore_from removed=0 restored=0 pair rel src dst seen=" "
  restore_from="$(newest_backup || true)"

  for pair in "${full_links[@]}" "${minimal_links[@]}"; do
    rel="${pair##*:}"
    dst="${HOME}/${rel}"

    # .vimrc is claimed by both link sets. Consider each target once, or the
    # second pass reports the file we just restored as "not ours".
    case "${seen}" in *" ${rel} "*) continue ;; esac
    seen="${seen}${rel} "

    if [ ! -L "${dst}" ]; then
      [ -e "${dst}" ] && echo "keep ${dst} (not our symlink)"
      continue
    fi

    # Match on "points anywhere inside this repo" rather than one exact source,
    # so a target owned by more than one link set (.vimrc) is handled whichever
    # profile installed it.
    src="$(readlink "${dst}")"
    case "${src}" in
      "${REPO}"/*) ;;
      *) echo "keep ${dst} (symlink points outside the repo)"; continue ;;
    esac

    rm -f "${dst}"
    echo "rm   ${dst}"
    removed=$((removed + 1))

    if [ -n "${restore_from}" ] && [ -e "${restore_from}/${rel}" ]; then
      mkdir -p "$(dirname "${dst}")"
      cp -p "${restore_from}/${rel}" "${dst}"
      echo "rest ${dst} <- ${restore_from}/${rel}"
      restored=$((restored + 1))
    fi
  done

  # remove the server-profile block from ~/.bashrc
  if [ -f "${HOME}/.bashrc" ] && grep -qF "${BASHRC_MARKER}" "${HOME}/.bashrc"; then
    local tmp
    tmp="$(mktemp)"
    sed '/^# >>> dotfiles server profile >>>$/,/^# <<< dotfiles server profile <<<$/d' \
      "${HOME}/.bashrc" > "${tmp}"
    # drop the blank line the installer added ahead of the block
    printf '%s\n' "$(cat "${tmp}")" > "${HOME}/.bashrc"
    rm -f "${tmp}"
    echo "rm   ~/.bashrc server profile block"
  fi

  echo
  echo "Removed ${removed} symlink(s); restored ${restored} file(s)."
  if [ -z "${restore_from}" ]; then
    echo "No backup directory found under ~/.dotfiles-backup/."
  else
    echo "Restored from: ${restore_from}"
  fi
  echo "Dependencies (oh-my-zsh, vim-plug, ~/.config/nvim) were left in place."
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

case "${MODE}" in
  uninstall)
    uninstall_all
    echo
    echo "Done. Open a new shell."
    ;;

  minimal)
    if [ "${BOOTSTRAP}" = "yes" ]; then
      echo "note: --bootstrap is ignored with --minimal; the server profile has no dependencies"
    fi
    link_all "${minimal_links[@]}"

    # bashrc is appended, not symlinked: Debian/Ubuntu ship useful defaults in
    # ~/.bashrc and replacing the file wholesale loses them.
    if [ -f "${HOME}/.bashrc" ] && grep -qF "${BASHRC_MARKER}" "${HOME}/.bashrc"; then
      echo "ok   ~/.bashrc (already sourced)"
    else
      {
        echo ""
        echo "${BASHRC_MARKER}"
        echo "[ -f \"${REPO}/server/bashrc\" ] && . \"${REPO}/server/bashrc\""
        echo "# <<< dotfiles server profile <<<"
      } >> "${HOME}/.bashrc"
      echo "add  ~/.bashrc -> sources ${REPO}/server/bashrc"
    fi

    echo
    echo "Server profile installed. Run 'exec bash -l' or reconnect."
    ;;

  full)
    [ "${BOOTSTRAP}" = "yes" ] && bootstrap_deps

    # ssh follows the symlink to the repo file, so the repo copy is what it
    # checks; it refuses a config that is group- or world-writable.
    chmod 700 "${HOME}/.ssh" 2>/dev/null || true
    chmod 600 "${REPO}/ssh/config"

    link_all "${full_links[@]}"

    [ "${BOOTSTRAP}" = "yes" ] && bootstrap_vim_plugins

    if [ "${BOOTSTRAP}" != "yes" ] && [ ! -d "${HOME}/.oh-my-zsh" ]; then
      echo
      echo "note: oh-my-zsh is not installed. Re-run with --bootstrap to fetch dependencies."
    fi

    # git/gitconfig deliberately carries no [user] block so it can be public.
    # Without the local file git has no identity and commits fail outright.
    if [ ! -f "${HOME}/.gitconfig.local" ]; then
      echo
      echo "note: ~/.gitconfig.local is missing, so git has no author identity."
      echo "      cp ${REPO}/git/gitconfig.local.example ~/.gitconfig.local"
      echo "      then edit it with your name and email."
    fi

    echo
    echo "Done. Open a new shell to pick up the changes."
    ;;
esac
