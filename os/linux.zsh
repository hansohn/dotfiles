#!/usr/bin/env zsh
#
# Linux-only configuration. Sourced from zshrc when $OSTYPE is linux*.
#
# Targets Ubuntu primarily, Gentoo best-effort. Everything here degrades
# quietly: this file is expected to be read on boxes where half these tools
# are not installed.

#------------------------------------------------------------------------------
# APPLICATIONS
#------------------------------------------------------------------------------

# go
if command -v go &>/dev/null; then
  export GOPATH="${HOME}/go"
  export GOBIN="${GOPATH}/bin"
  path_add "${GOBIN}"
fi

# java -- no java_home on Linux; derive from the resolved binary
if command -v java &>/dev/null && [ -z "${JAVA_HOME:-}" ]; then
  JAVA_HOME="$(readlink -f "$(command -v java)" 2>/dev/null)"
  JAVA_HOME="${JAVA_HOME%/bin/java}"
  [ -d "${JAVA_HOME}" ] && export JAVA_HOME || unset JAVA_HOME
fi

#------------------------------------------------------------------------------
# ALIASES (GNU userland)
#------------------------------------------------------------------------------

alias ls='ls --color=auto'
alias ll='ls -lh --color=auto'

# GNU stat: -c format. %s is size in bytes.
alias fs="stat -c '%s bytes'"

# dns -- varies by distro, so only alias what is actually present
if command -v resolvectl &>/dev/null; then
  alias flushdns='sudo resolvectl flush-caches'
elif command -v systemd-resolve &>/dev/null; then
  alias flushdns='sudo systemd-resolve --flush-caches'
fi

# interfaces
alias ipInfo0='ip addr show'
alias ipInfo1='ip -br addr'

#------------------------------------------------------------------------------
# CLIPBOARD
#------------------------------------------------------------------------------
# No pbcopy. Pick whichever of wayland/X11 is actually available; on a headless
# server there is usually none, so the helpers print to stdout instead of
# failing silently.

if command -v wl-copy &>/dev/null; then
  _copy() { wl-copy }
elif command -v xclip &>/dev/null; then
  _copy() { xclip -selection clipboard }
elif command -v xsel &>/dev/null; then
  _copy() { xsel --clipboard --input }
else
  _copy() { cat }   # headless: just print it
fi

alias pubkey="cat ~/.ssh/${SSH_KEY:-id_ed25519}.pub | _copy"
clip() { [ -f "$1" ] && _copy < "$1" }

#------------------------------------------------------------------------------
# EDITOR
#------------------------------------------------------------------------------
# Deliberately NOT aliasing vim=nvim. Most servers have vim and not neovim,
# and shadowing a working editor with a missing one is the worst possible
# failure mode at 3am. Only alias when neovim is genuinely present.

if command -v nvim &>/dev/null; then
  alias vim='nvim'
fi
