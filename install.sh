#!/usr/bin/env bash
#
# Interactive installer for this Neovim configuration.
#
#   ./install.sh [--name NAME] [--yes] [--skip-deps] [--dry-run] [--help]
#
# Installs the config into ${XDG_CONFIG_HOME:-~/.config}/nvim under your own
# name, sets up dependencies, plugins and language servers. An existing config
# is moved to a timestamped backup, never deleted.
#
# Written for bash 3.2 (the macOS default): no associative arrays, no mapfile.

set -u
set -o pipefail

# --- settings ----------------------------------------------------------------

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
TARGET=$CONFIG_HOME/nvim

TOKEN=morethancoder                 # placeholder replaced by the user's name
INSTALL_ITEMS="init.lua lua after LICENSE"
NVIM_VERSION=0.11.7                 # config needs 0.11.x (see README)
TOTAL_STEPS=7

# --- state -------------------------------------------------------------------

ASSUME_YES=0
DRY_RUN=0
SKIP_DEPS=0
NAME=""
OS=""
ARCH=""
PM=""
SUDO=""
STAGE=""
BACKUP=""
WORK=""
LOG=""
WARNINGS=""
KEEP_LOG=0

# --- ui ----------------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
  TTY=1
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
  TTY=0
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; RESET=""
fi

case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8*|*utf8*|*UTF8*)
    OK_G="✓"; FAIL_G="✗"; WARN_G="!"; ASK_G="?"; DOT_G="·"; RULE_G="─"
    SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) ;;
  *)
    OK_G="+"; FAIL_G="x"; WARN_G="!"; ASK_G="?"; DOT_G="-"; RULE_G="-"
    SPIN=('-' '\' '|' '/') ;;
esac

say()  { printf '%s\n' "$*"; }
dim()  { printf '  %s%s%s\n' "$DIM" "$*" "$RESET"; }
ok()   { printf '  %s%s%s %s\n' "$GREEN" "$OK_G" "$RESET" "$*"; }
bad()  { printf '  %s%s%s %s\n' "$RED" "$FAIL_G" "$RESET" "$*"; }
warn() { printf '  %s%s%s %s\n' "$YELLOW" "$WARN_G" "$RESET" "$*"; WARNINGS="$WARNINGS$*"$'\n'; }
die()  { bad "$*"; exit 1; }

rule() {
  local n=${1:-44} out="" i=0
  while [ "$i" -lt "$n" ]; do out="$out$RULE_G"; i=$((i + 1)); done
  printf '  %s%s%s\n' "$DIM" "$out" "$RESET"
}

banner() {
  say ""
  printf '  %sNeovim config installer%s\n' "$BOLD" "$RESET"
  rule
  dim "Installs into $TARGET"
  [ "$DRY_RUN" = 1 ] && printf '  %sDry run: nothing will be changed.%s\n' "$YELLOW" "$RESET"
}

STEP_NO=0
step() {
  STEP_NO=$((STEP_NO + 1))
  say ""
  printf '  %s%s[%s/%s]%s %s%s%s\n' "$BOLD" "$CYAN" "$STEP_NO" "$TOTAL_STEPS" "$RESET" "$BOLD" "$1" "$RESET"
}

# ask_yn "Question" y|n  ->  0 for yes, 1 for no
ask_yn() {
  local question=$1 default=${2:-y} hint ans
  [ "$default" = y ] && hint="[Y/n]" || hint="[y/N]"
  if [ "$ASSUME_YES" = 1 ]; then
    [ "$default" = y ] && return 0 || return 1
  fi
  while true; do
    printf '  %s%s%s %s %s%s%s ' "$CYAN" "$ASK_G" "$RESET" "$question" "$DIM" "$hint" "$RESET"
    read -r ans || die "Input closed before the installer finished."
    ans=$(printf '%s' "${ans:-$default}" | tr '[:upper:]' '[:lower:]')
    case $ans in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *) dim "Please answer y or n." ;;
    esac
  done
}

# run "Label" command [args...]  - runs quietly with a spinner, logs output.
# RUN_TIMEOUT (seconds) kills a command that hangs.
run() {
  local label=$1; shift
  if [ "$DRY_RUN" = 1 ]; then
    dim "would run: $*"
    return 0
  fi
  printf '\n=== %s\n$ %s\n' "$label" "$*" >>"$LOG"
  "$@" >>"$LOG" 2>&1 &
  local pid=$! i=0 rc started=$SECONDS limit=${RUN_TIMEOUT:-1200}
  if [ "$TTY" = 1 ]; then
    printf '\033[?25l'
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r  %s%s%s %s' "$CYAN" "${SPIN[$((i % ${#SPIN[@]}))]}" "$RESET" "$label"
      i=$((i + 1))
      if [ $((SECONDS - started)) -ge "$limit" ]; then
        kill "$pid" 2>/dev/null
        printf '\n=== timed out after %ss\n' "$limit" >>"$LOG"
        break
      fi
      sleep 0.1
    done
    printf '\r\033[K\033[?25h'
  fi
  wait "$pid"; rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "$label"
  else
    bad "$label"
    KEEP_LOG=1
    tail -n 12 "$LOG" | sed 's/^/      /'
    dim "Full log: $LOG"
  fi
  return "$rc"
}

# --- helpers -----------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

sha256() {
  if have sha256sum; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Print the Neovim version (e.g. 0.11.1), or nothing if nvim is missing.
nvim_version() {
  have nvim || return 0
  nvim --version 2>/dev/null | sed -n '1s/^NVIM v\([0-9.]*\).*/\1/p'
}

cleanup() {
  local rc=$?
  [ "$TTY" = 1 ] && printf '\033[?25h'
  [ -n "$STAGE" ] && rm -rf "$STAGE"
  [ -n "$WORK" ] && rm -rf "$WORK"
  # Interrupted between "move old config away" and "move new config in".
  if [ -n "$BACKUP" ] && [ ! -e "$TARGET" ] && [ -e "$BACKUP" ]; then
    mv "$BACKUP" "$TARGET" && printf '\n  Restored your previous config to %s\n' "$TARGET"
  fi
  if [ "$rc" -eq 0 ] && [ "$KEEP_LOG" = 0 ]; then
    [ -n "$LOG" ] && rm -f "$LOG"
  elif [ "$rc" -eq 0 ]; then
    printf '  Log kept at %s\n\n' "$LOG"
  elif [ -n "$LOG" ] && [ -s "$LOG" ]; then
    printf '\n  Installer stopped. Log kept at %s\n\n' "$LOG"
  fi
}

usage() {
  cat <<EOF
Usage: ./install.sh [options]

Options:
  -n, --name NAME   name for your config module (skips the prompt)
  -y, --yes         accept the default answer to every question
      --skip-deps   do not check or install system tools
      --dry-run     show what would happen without changing anything
  -h, --help        show this help
EOF
}

# --- step 1: environment -----------------------------------------------------

step_environment() {
  step "Environment"

  case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)  OS=linux ;;
    *) die "Unsupported system: $(uname -s). This installer supports macOS and Linux." ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) ARCH=arm64 ;;
    x86_64|amd64)  ARCH=x86_64 ;;
    *) die "Unsupported architecture: $(uname -m)." ;;
  esac

  if [ "$OS" = macos ]; then
    local b
    have brew || for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$b" ] && eval "$("$b" shellenv)" && break
    done
    have brew && PM=brew
  else
    if have apt-get; then PM=apt
    elif have dnf; then PM=dnf
    elif have pacman; then PM=pacman
    else
      local b
      for b in /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
        [ -x "$b" ] && eval "$("$b" shellenv)" && PM=brew && break
      done
      have brew && PM=brew
    fi
  fi

  [ "$(id -u)" -ne 0 ] || die "Do not run this as root; it installs into your own home directory."

  [ -f "$SRC_DIR/init.lua" ] && [ -d "$SRC_DIR/lua/$TOKEN" ] \
    || die "Run this from a full clone of the repo ($SRC_DIR is missing init.lua or lua/$TOKEN)."

  if [ -d "$TARGET" ] && [ "$(cd "$TARGET" && pwd -P)" = "$SRC_DIR" ]; then
    bad "This clone lives at $TARGET, the install location."
    dim "Clone it somewhere else, then run the installer from there:"
    dim "  git clone https://github.com/morethancoder/nvim-config.git ~/nvim-config"
    dim "  cd ~/nvim-config && ./install.sh"
    exit 1
  fi

  local os_label
  if [ "$OS" = macos ]; then os_label="macOS $(sw_vers -productVersion 2>/dev/null)"
  else os_label=$( ( . /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-Linux}" ) || printf 'Linux')
  fi
  ok "$os_label $DOT_G $ARCH $DOT_G ${PM:-no package manager found}"
}

# --- step 2: name ------------------------------------------------------------

normalize_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' -' '__' | sed 's/[^a-z0-9_]//g'
}

# Print a reason and return 1 if the name cannot be used as a Lua module name.
validate_name() {
  case $1 in
    vim|lua|nvim|packer|plugin|after|init|mason|telescope|harpoon|lualine|treesitter|formatter|luasnip|cmp|lspconfig|plenary)
      echo "\"$1\" clashes with a built-in or plugin module"; return 1 ;;
  esac
  if ! [[ $1 =~ ^[a-z][a-z0-9_]{1,31}$ ]]; then
    echo "use 2-32 characters: lowercase letters, digits or _, starting with a letter"
    return 1
  fi
}

step_name() {
  step "Your name"
  dim "Used as the Lua module for this config: lua/<name>/"

  local suggestion candidate reason
  suggestion=$(normalize_name "${USER:-$(id -un)}")

  if [ -n "$NAME" ]; then
    candidate=$(normalize_name "$NAME")
    reason=$(validate_name "$candidate") || die "Invalid --name: $reason"
    NAME=$candidate
  elif [ "$ASSUME_YES" = 1 ]; then
    reason=$(validate_name "$suggestion") || die "Cannot derive a name from \$USER ($reason). Pass --name."
    NAME=$suggestion
  else
    while true; do
      printf '  %s%s%s Name %s[%s]%s ' "$CYAN" "$ASK_G" "$RESET" "$DIM" "$suggestion" "$RESET"
      read -r candidate || die "Input closed before the installer finished."
      candidate=$(normalize_name "${candidate:-$suggestion}")
      if reason=$(validate_name "$candidate"); then NAME=$candidate; break; fi
      warn "$reason"
    done
  fi
  ok "Module name: $NAME"
}

# --- step 3: neovim ----------------------------------------------------------

nvim_asset() { # sets ASSET and SHA for this OS/arch
  case "$OS-$ARCH" in
    macos-arm64)   ASSET=nvim-macos-arm64;   SHA=9c84686ce84bbab725ff3d88ca3ac1d6da5a72128b68d9dd8094e34d4049a126 ;;
    macos-x86_64)  ASSET=nvim-macos-x86_64;  SHA=014649c0c75e188fd70d40f787ee7cb83e7c2926264cd4e72c300d0198922371 ;;
    linux-arm64)   ASSET=nvim-linux-arm64;   SHA=99bb3c53604e83ce18fc0b459e34cf1a5e212f4e5fbe2eb136b3c18092ae9905 ;;
    linux-x86_64)  ASSET=nvim-linux-x86_64;  SHA=38a7c6317f94503841096c00e8fde05ef04b9472fc9d7d62b6e033cecd6f7991 ;;
    *) return 1 ;;
  esac
}

install_nvim() {
  local ASSET SHA dest="$HOME/.local/nvim-$NVIM_VERSION" bin="$HOME/.local/bin"
  nvim_asset || die "No Neovim release for $OS/$ARCH."
  local url="https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/$ASSET.tar.gz"
  local archive="$WORK/$ASSET.tar.gz"

  if [ -e "$bin/nvim" ] && [ ! -L "$bin/nvim" ]; then
    die "$bin/nvim exists and is not a symlink; move it away and re-run."
  fi
  [ "$DRY_RUN" = 1 ] || mkdir -p "$bin" "$HOME/.local"

  run "Downloading Neovim $NVIM_VERSION" curl -fsSL -o "$archive" "$url" || return 1
  if [ "$DRY_RUN" = 0 ]; then
    [ "$(sha256 "$archive")" = "$SHA" ] || die "Checksum mismatch for $ASSET.tar.gz; refusing to install."
    ok "Checksum verified"
  fi
  run "Extracting to $dest" bash -c "rm -rf '$dest' && tar -xzf '$archive' -C '$WORK' && mv '$WORK/$ASSET' '$dest'" || return 1
  run "Linking $bin/nvim" ln -sfn "$dest/bin/nvim" "$bin/nvim" || return 1

  PATH="$bin:$PATH"
  if [ "$DRY_RUN" = 0 ] && [ "$(PATH="$ORIG_PATH" command -v nvim || true)" != "$bin/nvim" ]; then
    warn "Put $bin first on your PATH so your shell finds this Neovim:"
    dim "  export PATH=\"$bin:\$PATH\""
  fi
}

step_neovim() {
  step "Neovim"
  local v
  v=$(nvim_version)
  case $v in
    0.11.*) ok "Neovim $v ($(command -v nvim))"; return 0 ;;
    "")     printf '  %s%s%s Neovim is not installed.\n' "$YELLOW" "$WARN_G" "$RESET" ;;
    *)      printf '  %s%s%s Neovim %s found, but this config needs 0.11.x.\n' "$YELLOW" "$WARN_G" "$RESET" "$v" ;;
  esac
  dim "The config is pinned to plugins that only work on Neovim 0.11.x."
  if ask_yn "Install Neovim $NVIM_VERSION to ~/.local (existing installs are untouched)?" y; then
    install_nvim || die "Neovim install failed."
  else
    have nvim || [ "$DRY_RUN" = 1 ] || die "Neovim is required. Install 0.11.x and re-run."
    warn "Continuing with Neovim ${v:-?}; plugins may not work."
  fi
}

# --- step 4: tools -----------------------------------------------------------

REQUIRED_TOOLS="git curl unzip tar cc make"
RECOMMENDED_TOOLS="node ripgrep"

optional_tools() {
  local t="go stylua"
  [ "$OS" = linux ] && t="$t clipboard"
  [ "$OS" = macos ] && [ "$PM" = brew ] && t="$t font"
  echo "$t"
}

tool_purpose() {
  case $1 in
    git) echo "downloads plugins" ;;
    curl) echo "downloads packages" ;;
    unzip|tar) echo "unpacks language servers" ;;
    cc) echo "builds Treesitter parsers" ;;
    make) echo "builds plugins" ;;
    node) echo "runs TypeScript/HTML/Tailwind servers" ;;
    ripgrep) echo "Telescope grep" ;;
    go) echo "gopls and templ" ;;
    stylua) echo "Lua formatter" ;;
    clipboard) echo "system clipboard" ;;
    font) echo "Nerd Font for statusline icons" ;;
  esac
}

tool_present() {
  case $1 in
    cc) have cc || have gcc || have clang ;;
    node) have node && have npm ;;
    ripgrep) have rg ;;
    clipboard) have xclip || have wl-copy ;;
    font) brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1 ;;
    *) have "$1" ;;
  esac
}

# Package(s) providing a tool for the detected package manager (empty = none).
pkgs_for() {
  case "$PM:$1" in
    brew:git|brew:curl|brew:unzip|brew:node|brew:go|brew:stylua|brew:ripgrep) echo "$1" ;;
    brew:font) echo font-jetbrains-mono-nerd-font ;;
    apt:git|apt:curl|apt:unzip|apt:tar|apt:ripgrep) echo "$1" ;;
    apt:cc|apt:make) echo build-essential ;;
    apt:node) echo "nodejs npm" ;;
    apt:go) echo golang-go ;;
    dnf:git|dnf:curl|dnf:unzip|dnf:tar|dnf:make|dnf:go|dnf:ripgrep) echo "$1" ;;
    dnf:cc) echo gcc ;;
    dnf:node) echo "nodejs npm" ;;
    pacman:git|pacman:curl|pacman:unzip|pacman:tar|pacman:go|pacman:ripgrep|pacman:stylua) echo "$1" ;;
    pacman:cc|pacman:make) echo base-devel ;;
    pacman:node) echo "nodejs npm" ;;
    apt:clipboard|dnf:clipboard|pacman:clipboard)
      if [ -n "${WAYLAND_DISPLAY:-}" ]; then echo wl-clipboard; else echo xclip; fi ;;
  esac
}

pm_install() {
  case $PM in
    brew)   run "Installing $*" brew install "$@" ;;
    apt)    run "Refreshing package index" $SUDO apt-get update &&
            run "Installing $*" $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
    dnf)    run "Installing $*" $SUDO dnf install -y "$@" ;;
    pacman) run "Installing $*" $SUDO pacman -S --needed --noconfirm "$@" ;;
  esac
}

step_tools() {
  step "Tools"
  if [ "$SKIP_DEPS" = 1 ]; then dim "Skipped (--skip-deps)"; return 0; fi

  local t missing_main="" missing_opt="" label
  for t in $REQUIRED_TOOLS $RECOMMENDED_TOOLS $(optional_tools); do
    if tool_present "$t"; then
      printf '  %s%s%s %-10s %s%s%s\n' "$GREEN" "$OK_G" "$RESET" "$t" "$DIM" "$(tool_purpose "$t")" "$RESET"
    else
      case " $REQUIRED_TOOLS $RECOMMENDED_TOOLS " in
        *" $t "*) label="missing"; missing_main="$missing_main $t" ;;
        *)        label="optional"; missing_opt="$missing_opt $t" ;;
      esac
      printf '  %s%s%s %-10s %s%s (%s)%s\n' "$YELLOW" "$FAIL_G" "$RESET" "$t" "$DIM" "$(tool_purpose "$t")" "$label" "$RESET"
    fi
  done
  [ -z "$missing_main$missing_opt" ] && { ok "Everything is installed"; return 0; }

  # Turn tool lists into package lists; note tools we cannot install.
  local pkgs="" casks="" manual="" p
  collect() { # $1 = tools; appends to pkgs/casks/manual
    for t in $1; do
      p=$(pkgs_for "$t")
      if [ -z "$p" ]; then manual="$manual $t"
      elif [ "$t" = font ]; then casks="$casks $p"
      else case " $pkgs " in *" $p "*) ;; *) pkgs="$pkgs $p" ;; esac
      fi
    done
  }

  say ""
  if [ -z "$PM" ]; then
    warn "No supported package manager found (Homebrew, apt, dnf, pacman)."
    dim "Install manually:$missing_main$missing_opt"
  else
    if [ -n "$missing_main" ]; then
      collect "$missing_main"
      if [ -n "$pkgs" ] && ask_yn "Install missing tools with $PM (${pkgs# })?" y; then
        [ "$PM" != brew ] && [ "$DRY_RUN" = 0 ] && {
          have sudo || die "sudo is required to install packages. Run as an admin user or install manually:$pkgs"
          SUDO=sudo; dim "Administrator access is needed."; sudo -v || die "sudo failed."
        }
        [ "$PM" != brew ] && [ "$DRY_RUN" = 1 ] && SUDO=sudo
        pm_install $pkgs || die "Package installation failed."
      fi
    fi
    if [ -n "$missing_opt" ]; then
      pkgs=""; casks=""
      collect "$missing_opt"
      if { [ -n "$pkgs" ] || [ -n "$casks" ]; } && ask_yn "Also install optional tools (${pkgs# }${casks})?" n; then
        if [ "$PM" != brew ] && [ -z "$SUDO" ] && [ "$DRY_RUN" = 0 ]; then
          have sudo || die "sudo is required to install packages."
          SUDO=sudo; sudo -v || die "sudo failed."
        fi
        [ -n "$pkgs" ] && { pm_install $pkgs || warn "Some optional tools failed to install."; }
        [ -n "$casks" ] && { run "Installing $casks" brew install --cask $casks || warn "Font install failed."; }
      fi
    fi
  fi
  [ -n "$manual" ] && dim "Not available from $PM, install yourself if needed:$manual"
  case "$manual" in
    *" cc"*|*" make"*) [ "$OS" = macos ] && dim "Compiler tools: run  xcode-select --install" ;;
  esac

  # Hard requirements.
  local still=""
  for t in $REQUIRED_TOOLS; do
    tool_present "$t" || still="$still $t"
  done
  if [ -n "$still" ] && [ "$DRY_RUN" = 0 ]; then
    die "Required tools still missing:$still"
  fi
}

# --- step 5: config ----------------------------------------------------------

step_config() {
  step "Install config"
  local item
  if [ "$DRY_RUN" = 1 ]; then
    [ -e "$TARGET" ] && dim "would move existing $TARGET to a timestamped backup"
    dim "would copy: $INSTALL_ITEMS"
    [ "$NAME" != "$TOKEN" ] && dim "would rename lua/$TOKEN to lua/$NAME and update references"
    dim "would create ~/.vim/undodir"
    return 0
  fi

  mkdir -p "$CONFIG_HOME" || die "Cannot create $CONFIG_HOME."
  STAGE=$(mktemp -d "$CONFIG_HOME/.nvim-install.XXXXXX") || die "Cannot create a staging directory."

  for item in $INSTALL_ITEMS; do
    cp -RL "$SRC_DIR/$item" "$STAGE/$item" || die "Failed to copy $item."
  done
  find "$STAGE" -name .DS_Store -delete

  if [ "$NAME" != "$TOKEN" ]; then
    mv "$STAGE/lua/$TOKEN" "$STAGE/lua/$NAME" || die "Failed to rename lua/$TOKEN."
    local f
    find "$STAGE/init.lua" "$STAGE/lua" "$STAGE/after" -type f -name '*.lua' | while IFS= read -r f; do
      sed "s/$TOKEN/$NAME/g" "$f" > "$f.tmp" && mv "$f.tmp" "$f" || exit 1
    done || die "Failed to update references to $TOKEN."
  fi

  # Verify the staged copy before it replaces anything.
  [ -f "$STAGE/lua/$NAME/init.lua" ] || die "Staged config is incomplete (lua/$NAME/init.lua)."
  grep -q "require(\"$NAME\")" "$STAGE/init.lua" || die "init.lua does not load $NAME."
  if [ "$NAME" != "$TOKEN" ] && grep -rq "$TOKEN" "$STAGE"; then
    die "Leftover references to $TOKEN in the staged config."
  fi
  ok "Prepared config as lua/$NAME"

  if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    BACKUP="$TARGET.bak-$(date +%Y%m%d-%H%M%S)"
    local n=1
    while [ -e "$BACKUP" ] || [ -L "$BACKUP" ]; do BACKUP="$TARGET.bak-$(date +%Y%m%d-%H%M%S)-$n"; n=$((n + 1)); done
    mv "$TARGET" "$BACKUP" || die "Could not back up $TARGET."
    ok "Backed up existing config to $BACKUP"
  fi
  if ! mv "$STAGE" "$TARGET"; then
    [ -n "$BACKUP" ] && mv "$BACKUP" "$TARGET"
    die "Could not install the config."
  fi
  STAGE=""
  ok "Installed to $TARGET"

  mkdir -p "$HOME/.vim/undodir" && ok "Created ~/.vim/undodir"
}

# --- step 6: plugins ---------------------------------------------------------

step_plugins() {
  step "Plugins"
  local packer_dir="$DATA_HOME/nvim/site/pack/packer/start/packer.nvim"
  [ -d "$packer_dir" ] || run "Installing packer.nvim" git clone --depth 1 https://github.com/wbthomason/packer.nvim "$packer_dir" \
    || die "Could not install packer.nvim."

  # The config does not load packer.lua at startup, so source it for the sync.
  RUN_TIMEOUT=1500 run "Syncing plugins (this can take a few minutes)" \
    nvim --headless \
      -c "lua dofile(vim.fn.stdpath('config') .. '/lua/$NAME/packer.lua')" \
      -c "autocmd User PackerComplete quitall" \
      -c "PackerSync" \
    || die "Plugin sync failed."

  if [ "$DRY_RUN" = 0 ]; then
    local start="$DATA_HOME/nvim/site/pack/packer/start" p
    for p in telescope.nvim nvim-treesitter lsp-zero.nvim mason.nvim; do
      [ -d "$start/$p" ] || die "Plugin $p did not install. See the log for details."
    done
  fi

  # Parsers come from the config's own ensure_installed list.
  RUN_TIMEOUT=900 run "Installing Treesitter parsers" nvim --headless \
    -c "lua vim.cmd('TSInstallSync ' .. table.concat(require('nvim-treesitter.configs').get_ensure_installed_parsers(), ' '))" \
    -c "qa" \
    || warn "Treesitter parsers failed to build; run :TSUpdate inside Neovim."
}

# --- step 7: language servers ------------------------------------------------

MASON_LUA='local pkgs = vim.split(vim.env.NVIM_CFG_MASON_PKGS or "", " ", { trimempty = true })
require("mason").setup()
local registry = require("mason-registry")
local remaining, failed = #pkgs, {}

local function done(name, installed)
  if not installed then table.insert(failed, name) end
  remaining = remaining - 1
end

local function start()
  for _, name in ipairs(pkgs) do
    local found, pkg = pcall(registry.get_package, name)
    if not found then
      done(name, false)
    elseif pkg:is_installed() then
      done(name, true)
    else
      pkg:install():once("closed", function() done(name, pkg:is_installed()) end)
    end
  end
end

registry.update(function() vim.schedule(start) end)
vim.wait(900000, function() return remaining <= 0 end, 200)

if #failed > 0 then
  io.stderr:write("FAILED: " .. table.concat(failed, " ") .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa")
'

step_servers() {
  step "Language servers"
  local pkgs=""
  dim "Installed with Mason. Add or remove servers later with :Mason."

  if tool_present node; then
    ask_yn "Web servers (TypeScript, HTML, Tailwind)?" y \
      && pkgs="typescript-language-server html-lsp tailwindcss-language-server"
    if [ -n "$pkgs" ]; then
      if have cargo; then pkgs="$pkgs htmx-lsp"; else dim "Skipping htmx-lsp (needs cargo)."; fi
    fi
  else
    dim "Skipping web servers (node not found)."
  fi
  if have go; then
    ask_yn "Go servers (gopls, templ)?" y && pkgs="$pkgs gopls templ"
  else
    dim "Skipping Go servers (go not found)."
  fi
  pkgs=${pkgs# }
  [ -z "$pkgs" ] && { ok "Nothing selected"; return 0; }

  if [ "$DRY_RUN" = 1 ]; then dim "would install with Mason: $pkgs"; return 0; fi
  printf '%s' "$MASON_LUA" > "$WORK/mason.lua"
  RUN_TIMEOUT=1200 run "Installing $(printf '%s' "$pkgs" | wc -w | tr -d ' ') language servers" \
    env NVIM_CFG_MASON_PKGS="$pkgs" NVIM_CFG_MASON_LUA="$WORK/mason.lua" \
    nvim --headless -c "lua dofile(vim.env.NVIM_CFG_MASON_LUA)" \
    || warn "Some language servers failed; install them from :Mason."
}

# --- finish ------------------------------------------------------------------

finish() {
  say ""
  rule
  if [ "$DRY_RUN" = 1 ]; then
    say "  ${BOLD}Dry run complete.${RESET} Nothing was changed."
    say ""
    return 0
  fi

  local out
  out=$(nvim --headless "+qa" 2>&1) || true
  if [ -n "$out" ]; then
    warn "Neovim printed messages on startup; check :messages after launching."
    printf '%s\n' "$out" | head -n 5 | sed 's/^/      /'
  fi

  say "  ${BOLD}${GREEN}Installed.${RESET}"
  say ""
  printf '  %-9s %s\n' "Config" "$TARGET"
  printf '  %-9s %s\n' "Module" "lua/$NAME"
  [ -n "$BACKUP" ] && printf '  %-9s %s\n' "Backup" "$BACKUP"
  say ""
  say "  Next"
  dim "1. Set a Nerd Font as your terminal font (icons in the statusline)."
  dim "2. Run nvim and check :checkhealth."
  dim "3. Language servers not covered here (ccls, cmake) can be added via :Mason."
  if [ -n "$WARNINGS" ]; then
    say ""
    printf '  %sNotes%s\n' "$YELLOW" "$RESET"
    printf '%s' "$WARNINGS" | sed 's/^/    /'
  fi
  say ""
}

# --- main --------------------------------------------------------------------

ORIG_PATH=$PATH

while [ $# -gt 0 ]; do
  case $1 in
    -n|--name)   [ $# -ge 2 ] || { echo "--name needs a value" >&2; exit 2; }; NAME=$2; shift ;;
    --name=*)    NAME=${1#--name=} ;;
    -y|--yes)    ASSUME_YES=1 ;;
    --skip-deps) SKIP_DEPS=1 ;;
    --dry-run)   DRY_RUN=1 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ "$ASSUME_YES" = 0 ] && [ ! -t 0 ]; then
  echo "Interactive input is required. Run this in a terminal, or pass --yes." >&2
  exit 2
fi

LOG=$(mktemp "${TMPDIR:-/tmp}/nvim-config-install.XXXXXX") || exit 1
WORK=$(mktemp -d "${TMPDIR:-/tmp}/nvim-config.XXXXXX") || exit 1
trap cleanup EXIT
trap 'printf "\n"; warn "Interrupted."; exit 130' INT TERM

banner
step_environment
step_name
step_neovim
step_tools
step_config
step_plugins
step_servers
finish
