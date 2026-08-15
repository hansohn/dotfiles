#!/usr/bin/env zsh
#
# macOS-only configuration. Sourced from zshrc when $OSTYPE is darwin*.

#------------------------------------------------------------------------------
# HOMEBREW
#------------------------------------------------------------------------------

# BREW_PREFIX is set in zsh/zshrc, before the cross-platform app blocks that
# need it. Only the macOS-specific bit lives here.
command -v brew &>/dev/null && export HOMEBREW_CASK_OPTS="--appdir=/Applications"

#------------------------------------------------------------------------------
# APPLICATIONS
#------------------------------------------------------------------------------

# feature toggles
ANACONDA_SHELL=false
CHEF_SHELL=false
MINICONDA_SHELL=false
RUBY_USE_BREW=false

# anaconda
if [ "$ANACONDA_SHELL" = true ] && [ -d "/usr/local/anaconda3" ]; then
  path_add "/usr/local/anaconda3/bin"
  eval "$(register-python-argcomplete conda)"
fi

# miniconda
if [ "$MINICONDA_SHELL" = true ] && [ -d "${BREW_PREFIX}/Caskroom/miniconda" ]; then
  eval "$(register-python-argcomplete conda)"
  if [ -x "${BREW_PREFIX}/Caskroom/miniconda/base/bin/conda" ]; then
    __conda_setup="$("${BREW_PREFIX}/Caskroom/miniconda/base/bin/conda" shell.zsh hook 2>/dev/null)"
    [ $? -eq 0 ] && eval "$__conda_setup" || path_add "${BREW_PREFIX}/Caskroom/miniconda/base/bin"
    unset __conda_setup
  fi
fi

# cassandra
path_add "/opt/dsc-cassandra/current/bin"

# chef
if [ "$CHEF_SHELL" = true ] && brew list | grep -q '^chefdk$'; then
  eval "$(chef shell-init bash)"
fi

# go
if [ -d "/usr/local/opt/go/libexec" ]; then
  export GOROOT="/usr/local/opt/go/libexec"
  export GOPATH="${HOME}/Code/go"
  export GOBIN="${GOPATH}/bin"
  path_add "${GOROOT}/bin"
fi

# hadoop
if [ -d "/usr/local/Cellar/hadoop" ]; then
  export HADOOP_VERSION="$(brew list --versions hadoop | awk '{ print $2 }')"
  export HADOOP_HOME="/usr/local/Cellar/hadoop/${HADOOP_VERSION}"
  export HADOOP_CONF_DIR="${HADOOP_HOME}/libexec/etc/hadoop"
fi

# java
if [ -x "/usr/libexec/java_home" ] && java -version &>/dev/null; then
  export JAVA_HOME="$("/usr/libexec/java_home")"
  export JRE_HOME="${JAVA_HOME}/jre"
  path_add "${JAVA_HOME}/bin"
fi

# openssl
[ -d "/usr/local/opt/openssl" ] && export OPENSSL_ROOT_DIR="/usr/local/opt/openssl"

# ruby
[ "${RUBY_USE_BREW}" = true ] && path_add "/usr/local/opt/ruby/bin"

# google cloud sdk
if [ -f "${BREW_PREFIX}/share/google-cloud-sdk/path.zsh.inc" ]; then
  . "${BREW_PREFIX}/share/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "${BREW_PREFIX}/share/google-cloud-sdk/completion.zsh.inc" ]; then
  . "${BREW_PREFIX}/share/google-cloud-sdk/completion.zsh.inc"
fi

# git prompt (bash completion script shipped by brew's git)
if [ -f "${BREW_PREFIX}/opt/git/etc/bash_completion.d/git-prompt.sh" ]; then
  source "${BREW_PREFIX}/opt/git/etc/bash_completion.d/git-prompt.sh"

  export GIT_PS1_SHOWDIRTYSTATE=true
  export GIT_PS1_SHOWUPSTREAM="verbose"
  export GIT_PS1_DESCRIBE_STYLE="branch"
  export GIT_PS1_SHOWCOLORHINTS=true

  PROMPT_COMMAND='__git_ps1 "\u@\h[\w]" "\\\$ "'
fi

#------------------------------------------------------------------------------
# ALIASES (BSD userland)
#------------------------------------------------------------------------------

# BSD ls colorizes with -G; GNU ls uses --color and reads -G as --no-group
alias ls='ls -G'
alias ll='ls -Glh'

# BSD stat uses -f for format; GNU stat uses -f for --file-system
alias fs="stat -f '%z bytes'"

# clipboard
alias pubkey="cat ~/.ssh/${SSH_KEY:-id_ed25519}.pub | pbcopy"
clip() { [ -f "$1" ] && pbcopy < "$1" }

# dns / cache
alias flushcache="dscacheutil -flushcache"
alias flushdns="dscacheutil -flushcache; sudo killall -HUP mDNSResponder"

# homebrew
alias fixbrew='sudo chown -R "$USER":admin "$(brew --prefix)"'

# interfaces
alias ipInfo0='ipconfig getpacket en0'
alias ipInfo1='ipconfig getpacket en1'

# editor
alias vim='nvim'
