<div align="center">
  <h1>dotfiles</h1>
  <p>Shell, editor and terminal configuration for infrastructure and platform engineering</p>
  <p>
    <!-- Build Status -->
    <a href="https://github.com/hansohn/dotfiles/actions/workflows/validate.yml"><img src="https://img.shields.io/github/actions/workflow/status/hansohn/dotfiles/validate.yml?style=for-the-badge"></a>
    <!-- Github Tag -->
    <a href="https://github.com/hansohn/dotfiles/tags/"><img src="https://img.shields.io/github/v/tag/hansohn/dotfiles?style=for-the-badge&sort=semver"></a>
    <!-- License -->
    <a href="https://github.com/hansohn/dotfiles/blob/main/LICENSE.md"><img src="https://img.shields.io/github/license/hansohn/dotfiles.svg?style=for-the-badge"></a>
  </p>
</div>

## Description

Personal shell, vim, and tmux configuration. Primary target is macOS; the zsh
config is OS-guarded and also works on Linux. A separate dependency-free
profile exists for servers.

Files are stored without the leading dot so they stay visible in the repo;
`install.sh` maps them to their dotted targets in `$HOME`.

## Layout

### Shell

| Repo file | Symlinked to | Loaded when |
|---|---|---|
| `zsh/zshenv` | `~/.zshenv` | every zsh, always, first |
| `zsh/zprofile` | `~/.zprofile` | login shells |
| `zsh/zshrc` | `~/.zshrc` | interactive shells |
| `os/darwin.zsh` | *(sourced by `zshrc`)* | `$OSTYPE` is `darwin*` |
| `os/linux.zsh` | *(sourced by `zshrc`)* | `$OSTYPE` is `linux*` |

`zshrc` holds only what is portable. Anything whose flags or backing command
differ between BSD and GNU userland — `ls`, `stat`, clipboard, DNS flush,
interface listing — lives in the `os/` file for that platform, sourced last so
it wins. Two extension points are never committed: `~/.zshrc.local` for
machine-specific settings, and `~/.bashrc.local` for the server profile.

### Editors & terminal

| Repo file | Symlinked to |
|---|---|
| `vim/vimrc` | `~/.vimrc` |
| `vim/plugins.vim` | `~/.vim/plugins.vim` |
| `ghostty/config` | `~/.config/ghostty/config` |
| `tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |
| `powerline/config.json` | `~/.config/powerline/config.json` |
| `bat/config` | `~/.config/bat/config` |

### Tooling

| Repo file | Symlinked to |
|---|---|
| `git/gitconfig` | `~/.gitconfig` |
| `git/ignore` | `~/.config/git/ignore` |
| `git/gitconfig.local.example` | *(template — copy to `~/.gitconfig.local`)* |
| `gh/config.yml` | `~/.config/gh/config.yml` |
| `ssh/config` | `~/.ssh/config` |
| `k9s/config.yaml` | `~/.config/k9s/config.yaml` |
| `k9s/aliases.yaml` | `~/.config/k9s/aliases.yaml` |
| `k9s/skins/dracula.yaml` | `~/.config/k9s/skins/dracula.yaml` |
| `terraform/terraformrc` | `~/.terraformrc` |
| `claude/settings.json` | `~/.claude/settings.json` |
| `opencode/opencode.json` | `~/.config/opencode/opencode.json` |
| `opencode/tui.json` | `~/.config/opencode/tui.json` |

### Server profile

| Repo file | Installed as | Notes |
|---|---|---|
| `server/vimrc` | `~/.vimrc` | no plugins, no colorscheme, vim 7.x+ |
| `server/bashrc` | *appended to* `~/.bashrc` | no oh-my-zsh, no network calls |

`server/bashrc` is appended rather than symlinked — Debian/Ubuntu ship useful
defaults in `~/.bashrc` and replacing it wholesale loses them.

`vim/vimrc` is sourced only by plain `/usr/bin/vim` — on macOS `zshrc` sets
`alias vim='nvim'`. Note `git/gitconfig` sets `editor = vim`; git does not expand
shell aliases, so git genuinely opens real vim.

## Install

```sh
git clone git@github.com:hansohn/dotfiles.git ~/Code/dotfiles
cd ~/Code/dotfiles

make install/bootstrap    # workstation: full config + dependencies
make install              # workstation: symlinks only
make install/minimal      # server: vim + bash, zero dependencies
make uninstall            # remove symlinks, restore newest backup
```

`make` on its own lists every target. The underlying `./install.sh` takes the
same options (`--bootstrap`, `--minimal`, `--uninstall`, `--help`) if you would
rather not go through make.

### Git identity

`git/gitconfig` carries **no `[user]` block** so this repo can be public. It
ends with an `[include]` of `~/.gitconfig.local`, which is never committed:

```sh
cp git/gitconfig.local.example ~/.gitconfig.local   # then edit it
```

Without that file git has no author identity and commits fail. The installer
says so if it is missing. The same hook is how a work machine carries a
different address — see the `includeIf` example in the template.

### Dependencies

`--bootstrap` installs only what the configs in this repo need in order to load
without error: oh-my-zsh, the `zsh-autosuggestions` and `zsh-syntax-highlighting`
custom plugins, vim-plug, and `hansohn/nvim` into `~/.config/nvim` (skipped if
anything is already there). System packages — zsh, vim, brew formulae — are
`osx-setup`'s job. Every step is a no-op if the target already exists.

### Uninstall

`make uninstall` removes **only** symlinks that point into this repo. A
real file, or a symlink pointing somewhere else, is reported and left alone. If
`~/.dotfiles-backup/` holds a matching file from a previous install, the newest
one is restored in place. Bootstrapped dependencies are deliberately left —
they are shared with other tools.

Symlinks point at this working tree, so editing `~/.zshrc` edits `zsh/zshrc`
and `git status` reflects it. Re-running `install.sh` is safe — it only
re-links what has drifted, and archives anything real it would replace to
`~/.dotfiles-backup/<timestamp>/`.

If you clone somewhere other than `~/Code/dotfiles`, export `DOTFILES` to that
path so `zshrc` can find the `os/` files.

## Development

```sh
make lint       # shellcheck the bash files, parse the zsh files
make test       # smoke-test on macOS (ZDOTDIR sandbox) and Linux (docker)
make validate   # both -- what CI runs
```

`make test/macos` runs against a throwaway `ZDOTDIR`, so it never touches
`$HOME`. `make test/linux` needs a running Docker daemon.

The `validate` workflow runs the same checks in GitHub Actions, plus a
bootstrap matrix on ubuntu and macos runners, an idempotency check, and a
server-profile job asserting vim starts with no errors and no Press-ENTER
prompt.

### Naming conventions

Shared with [`hansohn/mac-setup`](https://github.com/hansohn/mac-setup), so a
setting reads the same in either repo:

- `UPPER_SNAKE` for config and constants, `lower_snake` for a script's internal
  working variables.
- Domain first — `<DOMAIN>_<ATTRIBUTE>` — so everything about one tool sorts
  together.
- Feature toggles end in `_ENABLED`: `NVM_ENABLED`, `ANACONDA_ENABLED`,
  `CHEF_ENABLED`, `MINICONDA_ENABLED`, `RUBY_BREW_ENABLED`.
- Paths carry a type suffix: `_DIR`, `_FILE`, `_PATH`. No abbreviations.

One exception, and it matters: a variable another tool defines keeps that
tool's name. `SHOW_AWS_PROMPT` (`zsh/zshrc`) and `DEFAULT_USER` (referenced by
`prompt_context`) are both read by oh-my-zsh — `agnoster.zsh-theme` and
`plugins/aws` — so renaming them to fit the list above would quietly turn off
what they control rather than failing loudly.

## Linux notes

Verified on Ubuntu 24.04 with zsh 5.9. Gentoo is best-effort — the same guards
apply, but locales usually need generating first.

The full config loads cleanly with **no stderr** on a bare box with no
oh-my-zsh, no Homebrew, no cargo, and no generated locale. Specifically:

- **Locale** is only exported if `locale -a` actually lists it. Exporting
  `en_US.UTF-8` where it was never generated produces `setlocale` warnings on
  every command and breaks the agnoster prompt's glyphs.
- **`vim` is not aliased to `nvim`** unless neovim is genuinely installed.
  Shadowing a working editor with a missing one is the worst failure mode on a
  box you just SSH'd into.
- **Homebrew and cargo** sourcing is guarded; `zprofile` probes the Apple
  Silicon, Intel, and linuxbrew locations in turn.
- **oh-my-zsh** is sourced only if present, so the rest of the file still loads
  without it.

For boxes you only SSH into, prefer `--minimal`. Installing oh-my-zsh on a
production host costs startup time and buys little.

## Deliberately excluded

This repo is **public**, so nothing containing live credentials belongs in it.
That was the rule before it was published and it is enforced by CI now — see
the `gitleaks` job in [`validate.yml`](.github/workflows/validate.yml). Kept out
on purpose:

- **Anything holding credentials** — package-manager tokens, cluster and cloud
  auth material, app access tokens, keyrings, and private keys. Every candidate
  file was screened before it went in; nothing carrying a live credential is
  tracked here. All of `~/.ssh` is excluded except `config`.
- **Machine state, not configuration** — shell/python/vim histories,
  `.zcompdump*`, `.DS_Store`, `~/.claude.json` and `history.jsonl`, packer
  checkpoints, `.wget-hsts`, `.lesshst`, and `~/.config/helm/repositories.yaml`
  (regenerable via `helm repo add`).

## Not managed here

- **Neovim** — lives in its own repo, [`hansohn/nvim`](https://github.com/hansohn/nvim),
  cloned to `~/.config/nvim`. Note `zshrc` sets `alias vim='nvim'`, so `vim/vimrc`
  applies only when running `/usr/bin/vim` directly.
- **Machine bootstrap** — Homebrew formulae, casks, macOS defaults, and app
  setup live in [`hansohn/osx-setup`](https://github.com/hansohn/osx-setup).

## Known issues

Carried over from the live configs at seed time; not yet fixed. All are
macOS-side only — none affect Linux.

- `zshrc` prepends `/usr/local/bin` ahead of `/opt/homebrew/bin`, so Docker
  Desktop's `kubectl` shadows the Homebrew one.
- PATH is built in `zshrc` rather than `zprofile`, so nested interactive shells
  accumulate duplicate entries.
- `compinit` runs twice per startup — once via oh-my-zsh, once explicitly.
- Several blocks reference Intel-era `/usr/local` Homebrew paths that do not
  exist on Apple Silicon (anaconda, go, hadoop, openssl, ruby, cassandra, chef).
- The `git-prompt.sh` block sets `PROMPT_COMMAND`, a bash variable zsh ignores.

Fixed during the OS split, because leaving them would have meant writing
knowingly-broken code into `os/darwin.zsh`: `pubkey` now reads `id_ed25519.pub`
(the `id_rsa.pub` it referenced does not exist), `fixbrew` now chowns
`$(brew --prefix)` instead of a hardcoded `/usr/local`, and the duplicate
`wmip` definition is gone.

## Intentionally not carried over

Two lines from the original `.zshrc` were dropped in the OS split. Both were
already unreachable:

- `alias wmip="curl -w '\n' https://ipinfo.io/what-is-my-ip"` — the first of
  two `wmip` definitions. The second, `curl ipinfo.io`, always won.
- `export EDITOR="VIM"` — inside the `chef` block, which is gated on
  `CHEF_ENABLED=false` and never ran. `"VIM"` uppercase is not a valid editor
  command regardless. Nothing currently sets `EDITOR` on the workstation side;
  `server/bashrc` sets it to `vim`.

Everything else from the original file was relocated, not removed. The line
count fell from 350 to ~200 because ~100 lines were commented-out oh-my-zsh
template boilerplate; actual code lines went up.
