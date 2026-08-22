#!/usr/bin/env bash

set -u

MIN_NVIM="0.12.0"
MIN_GIT="2.19.0"
MIN_TREE_SITTER="0.26.1"
MODE="prompt"
ASSUME_YES=0
WITH_OPTIONAL=0
SKIP_EDITOR_BOOTSTRAP=0

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap.sh [options]

  --check             Check only; never install or run Neovim bootstrap
  --install           Install required and needed packages after showing the plan
  --yes               Do not prompt (requires --install)
  --with-optional     Also install supported optional tools
  --skip-editor       Do not install plugins, Mason tools, or Tree-sitter parsers
  -h, --help          Show this help

On Linux without a supported package manager, bootstrap can install official
Neovim, ripgrep, Tree-sitter CLI, and fd releases under /usr/local after confirmation.
EOF
}

while (($#)); do
  case "$1" in
    --check) MODE="check" ;;
    --install) MODE="install" ;;
    --yes) ASSUME_YES=1 ;;
    --with-optional) WITH_OPTIONAL=1 ;;
    --skip-editor) SKIP_EDITOR_BOOTSTRAP=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$ASSUME_YES" -eq 1 && "$MODE" != "install" ]]; then
  printf '%s\n' '--yes is only valid together with --install.' >&2
  exit 2
fi

version_ge() {
  local actual="$1" minimum="$2"
  local actual_major=0 actual_minor=0 actual_patch=0
  local wanted_major=0 wanted_minor=0 wanted_patch=0
  IFS=. read -r actual_major actual_minor actual_patch <<<"$actual"
  IFS=. read -r wanted_major wanted_minor wanted_patch <<<"$minimum"
  actual_minor="${actual_minor:-0}"
  actual_patch="${actual_patch:-0}"
  wanted_minor="${wanted_minor:-0}"
  wanted_patch="${wanted_patch:-0}"
  ((10#$actual_major > 10#$wanted_major)) && return 0
  ((10#$actual_major < 10#$wanted_major)) && return 1
  ((10#$actual_minor > 10#$wanted_minor)) && return 0
  ((10#$actual_minor < 10#$wanted_minor)) && return 1
  ((10#$actual_patch >= 10#$wanted_patch))
}

command_version() {
  local command_name="$1"
  shift
  command -v "$command_name" >/dev/null 2>&1 || return 1
  "$command_name" "$@" 2>&1 | sed -nE 's/.*[^0-9]([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' | head -n1
}

has_any() {
  local candidate
  for candidate in "$@"; do
    command -v "$candidate" >/dev/null 2>&1 && return 0
  done
  return 1
}

has_compiler() {
  has_any cc gcc clang
}

has_python_venv() {
  local candidate
  for candidate in python3 python; do
    command -v "$candidate" >/dev/null 2>&1 || continue
    "$candidate" -c 'import venv' >/dev/null 2>&1 && return 0
  done
  return 1
}

declare -a REPORT_LEVEL=()
declare -a REPORT_NAME=()
declare -a REPORT_STATE=()
declare -a REPORT_PURPOSE=()
declare -a REPORT_HINT=()

add_dependency() {
  REPORT_LEVEL+=("$1")
  REPORT_NAME+=("$2")
  REPORT_STATE+=("$3")
  REPORT_PURPOSE+=("$4")
  REPORT_HINT+=("$5")
}

collect_report() {
  REPORT_LEVEL=()
  REPORT_NAME=()
  REPORT_STATE=()
  REPORT_PURPOSE=()
  REPORT_HINT=()

  local nvim_version="" git_version="" tree_sitter_version=""
  nvim_version="$(command_version nvim --version || true)"
  git_version="$(command_version git --version || true)"
  tree_sitter_version="$(command_version tree-sitter --version || true)"

  local nvim_ok=0 git_ok=0 tree_sitter_ok=0
  [[ -n "$nvim_version" ]] && version_ge "$nvim_version" "$MIN_NVIM" && nvim_ok=1
  [[ -n "$git_version" ]] && version_ge "$git_version" "$MIN_GIT" && git_ok=1
  [[ -n "$tree_sitter_version" ]] && version_ge "$tree_sitter_version" "$MIN_TREE_SITTER" && tree_sitter_ok=1

  add_dependency required "Neovim >= $MIN_NVIM" "$nvim_ok" "run this configuration" "install a current Neovim release"
  add_dependency required "Git >= $MIN_GIT" "$git_ok" "clone Lazy.nvim and plugins" "install git with the detected package manager"
  add_dependency required "ripgrep (rg)" "$(has_any rg && echo 1 || echo 0)" "Telescope and project search/replace" "install ripgrep"
  add_dependency required "curl" "$(has_any curl && echo 1 || echo 0)" "download Tree-sitter parsers" "install curl"
  add_dependency required "tar" "$(has_any tar gtar && echo 1 || echo 0)" "extract Tree-sitter and Mason packages" "install GNU tar"
  add_dependency required "unzip" "$(has_any unzip && echo 1 || echo 0)" "extract Mason packages" "install unzip"
  add_dependency required "gzip" "$(has_any gzip && echo 1 || echo 0)" "extract Mason packages" "install gzip"
  add_dependency required "make" "$(has_any make && echo 1 || echo 0)" "build telescope-fzf-native" "install make or a build-essential/base-devel package"
  add_dependency required "C/C++ compiler" "$(has_compiler && echo 1 || echo 0)" "compile Tree-sitter parsers" "install GCC/Clang or Xcode Command Line Tools"
  add_dependency required "tree-sitter CLI >= $MIN_TREE_SITTER" "$tree_sitter_ok" "install the configured parsers" "install tree-sitter-cli, not the npm package"

  add_dependency needed "fd/fdfind" "$(has_any fd fdfind && echo 1 || echo 0)" "Python environment discovery" "install fd or fd-find"
  add_dependency needed "Node.js + npm" "$([[ $(has_any node && echo 1 || echo 0) -eq 1 && $(has_any npm && echo 1 || echo 0) -eq 1 ]] && echo 1 || echo 0)" "JSON/JavaScript tools and Copilot" "install the current Node.js LTS release with npm"
  add_dependency needed "Python 3 + venv" "$(has_python_venv && echo 1 || echo 0)" "Python LSP, formatter, and debugger tools" "install Python 3 and its venv package"

  add_dependency optional "uv" "$(has_any uv && echo 1 || echo 0)" "Python project/package commands" "install uv from its official package"
  add_dependency optional "Bear" "$(has_any bear && echo 1 || echo 0)" "capture Make compilation databases" "install bear or disable tasks.make.use_bear"
  add_dependency optional "ImageMagick" "$(has_any magick convert && echo 1 || echo 0)" "non-PNG image conversion in Snacks" "install ImageMagick"
  add_dependency optional "Nerd Font" "0" "file and UI icons (not automatically detectable)" "install one Nerd Font and select it in the terminal"
}

show_report() {
  local level index mark
  for level in required needed optional; do
    printf '\n%s:\n' "$(printf '%s' "$level" | tr '[:lower:]' '[:upper:]')"
    for ((index = 0; index < ${#REPORT_LEVEL[@]}; index++)); do
      [[ "${REPORT_LEVEL[$index]}" == "$level" ]] || continue
      if [[ "${REPORT_STATE[$index]}" == "1" ]]; then
        mark="OK"
      else
        mark="MISSING"
      fi
      printf '  [%-7s] %s - %s\n' "$mark" "${REPORT_NAME[$index]}" "${REPORT_PURPOSE[$index]}"
      if [[ "$mark" == "MISSING" ]]; then
        printf '            %s\n' "${REPORT_HINT[$index]}"
      fi
    done
  done
}

confirm() {
  local prompt="$1" answer
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  read -r -p "$prompt [y/N] " answer
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

OS_KIND=""
DISTRO_ID=""
PACKAGE_MANAGER=""
INSTALL_METHOD=""

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      OS_KIND="macos"
      if command -v brew >/dev/null 2>&1; then
        PACKAGE_MANAGER="brew"
      fi
      ;;
    Linux)
      OS_KIND="linux"
      if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
      else
        DISTRO_ID="unknown"
      fi
      case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop) command -v apt-get >/dev/null 2>&1 && PACKAGE_MANAGER="apt" ;;
        fedora|rhel|centos|rocky|almalinux) command -v dnf >/dev/null 2>&1 && PACKAGE_MANAGER="dnf" ;;
        arch|manjaro|endeavouros) command -v pacman >/dev/null 2>&1 && PACKAGE_MANAGER="pacman" ;;
        opensuse*|sles) command -v zypper >/dev/null 2>&1 && PACKAGE_MANAGER="zypper" ;;
        alpine) command -v apk >/dev/null 2>&1 && PACKAGE_MANAGER="apk" ;;
      esac
      if [[ -z "$PACKAGE_MANAGER" ]]; then
        case " $DISTRO_LIKE " in
          *" debian "*) command -v apt-get >/dev/null 2>&1 && PACKAGE_MANAGER="apt" ;;
          *" fedora "*|*" rhel "*) command -v dnf >/dev/null 2>&1 && PACKAGE_MANAGER="dnf" ;;
          *" arch "*) command -v pacman >/dev/null 2>&1 && PACKAGE_MANAGER="pacman" ;;
          *" suse "*) command -v zypper >/dev/null 2>&1 && PACKAGE_MANAGER="zypper" ;;
        esac
      fi
      ;;
    *) OS_KIND="unsupported" ;;
  esac
}

privileged_prefix() {
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    printf '%s' "sudo"
    return 0
  fi
  printf '%s\n' "Administrative privileges are required, but sudo is unavailable." >&2
  return 1
}

run_package_manager() {
  local privilege=""
  case "$PACKAGE_MANAGER" in
    brew)
      brew install neovim git ripgrep tree-sitter-cli gnu-tar fd node python cmake || return 1
      if [[ "$WITH_OPTIONAL" -eq 1 ]]; then
        brew install uv bear imagemagick || return 1
      fi
      ;;
    apt)
      privilege="$(privileged_prefix)" || return 1
      $privilege apt-get update || return 1
      $privilege apt-get install -y neovim git ripgrep curl unzip tar gzip build-essential cmake fd-find nodejs npm python3 python3-venv || return 1
      if [[ "$WITH_OPTIONAL" -eq 1 ]]; then
        $privilege apt-get install -y bear imagemagick || return 1
      fi
      ;;
    dnf)
      privilege="$(privileged_prefix)" || return 1
      $privilege dnf install -y neovim git ripgrep curl unzip tar gzip gcc gcc-c++ make cmake fd-find nodejs npm python3 || return 1
      if [[ "$WITH_OPTIONAL" -eq 1 ]]; then
        $privilege dnf install -y bear ImageMagick || return 1
      fi
      ;;
    pacman)
      privilege="$(privileged_prefix)" || return 1
      $privilege pacman -S --needed neovim git ripgrep curl unzip tar gzip base-devel cmake tree-sitter-cli fd nodejs npm python || return 1
      if [[ "$WITH_OPTIONAL" -eq 1 ]]; then
        $privilege pacman -S --needed uv bear imagemagick || return 1
      fi
      ;;
    zypper)
      privilege="$(privileged_prefix)" || return 1
      $privilege zypper --non-interactive install neovim git ripgrep curl unzip tar gzip gcc gcc-c++ make cmake fd nodejs npm python3 || return 1
      if [[ "$WITH_OPTIONAL" -eq 1 ]]; then
        $privilege zypper --non-interactive install bear ImageMagick || return 1
      fi
      ;;
    apk)
      privilege="$(privileged_prefix)" || return 1
      $privilege apk add neovim git ripgrep curl unzip tar gzip build-base cmake fd nodejs npm python3 py3-pip || return 1
      if [[ "$WITH_OPTIONAL" -eq 1 ]]; then
        $privilege apk add imagemagick || return 1
      fi
      ;;
    *)
      printf 'No supported package manager was detected; nothing was installed.\n' >&2
      return 1
      ;;
  esac
  return 0
}

detect_portable_target() {
  case "$(uname -m)" in
    x86_64|amd64)
      PORTABLE_NVIM_ARCH="x86_64"
      PORTABLE_RUST_TARGET="x86_64-unknown-linux-musl"
      ;;
    arm64|aarch64)
      PORTABLE_NVIM_ARCH="arm64"
      if ldd --version 2>&1 | grep -qi musl; then
        PORTABLE_RUST_TARGET="aarch64-unknown-linux-musl"
      else
        PORTABLE_RUST_TARGET="aarch64-unknown-linux-gnu"
      fi
      ;;
    *)
      printf 'Official portable binaries are not mapped for architecture %s.\n' "$(uname -m)" >&2
      return 1
      ;;
  esac
}

github_latest_tag() {
  local repository="$1" effective_url
  effective_url="$(curl -fsIL -o /dev/null -w '%{url_effective}' "https://github.com/${repository}/releases/latest")" || return 1
  case "$effective_url" in
    */tag/*) printf '%s' "${effective_url##*/}" ;;
    *) return 1 ;;
  esac
}

cleanup_portable_temp() {
  local temporary="$1" temp_root
  temp_root="${TMPDIR:-/tmp}"
  temp_root="${temp_root%/}"
  if [[ -n "$temporary" && -d "$temporary" && "$temporary" == "$temp_root/"* ]]; then
    rm -rf -- "$temporary"
  else
    printf 'Refusing to remove unexpected temporary path: %s\n' "$temporary" >&2
  fi
}

install_portable_archive_binary() {
  local binary_name="$1" url="$2" temporary archive binary privilege
  privilege="$(privileged_prefix)" || return 1
  temporary="$(mktemp -d)" || return 1
  archive="$temporary/asset"

  printf 'Downloading official %s binary from %s\n' "$binary_name" "$url"
  if ! curl -fL "$url" -o "$archive"; then
    cleanup_portable_temp "$temporary"
    return 1
  fi
  case "$url" in
    *.zip)
      unzip -q "$archive" -d "$temporary/unpacked" || {
        cleanup_portable_temp "$temporary"
        return 1
      }
      ;;
    *.tar.gz)
      mkdir -p "$temporary/unpacked"
      tar -xzf "$archive" -C "$temporary/unpacked" || {
        cleanup_portable_temp "$temporary"
        return 1
      }
      ;;
    *)
      printf 'Unsupported portable archive: %s\n' "$url" >&2
      cleanup_portable_temp "$temporary"
      return 1
      ;;
  esac

  binary="$(find "$temporary/unpacked" -type f -name "$binary_name" -print -quit)"
  if [[ -z "$binary" ]]; then
    printf 'The archive did not contain %s.\n' "$binary_name" >&2
    cleanup_portable_temp "$temporary"
    return 1
  fi
  $privilege mkdir -p /usr/local/bin || {
    cleanup_portable_temp "$temporary"
    return 1
  }
  $privilege install -m 0755 "$binary" "/usr/local/bin/$binary_name" || {
    cleanup_portable_temp "$temporary"
    return 1
  }
  cleanup_portable_temp "$temporary"
}

install_portable_neovim() {
  local temporary archive source_dir destination link_target privilege url
  if ldd --version 2>&1 | grep -qi musl; then
    printf 'The official Neovim Linux archive requires glibc; it was not installed on this musl system.\n' >&2
    return 1
  fi
  privilege="$(privileged_prefix)" || return 1
  temporary="$(mktemp -d)" || return 1
  archive="$temporary/nvim.tar.gz"
  url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${PORTABLE_NVIM_ARCH}.tar.gz"

  printf 'Downloading the official Neovim archive from %s\n' "$url"
  if ! curl -fL "$url" -o "$archive" || ! tar -xzf "$archive" -C "$temporary"; then
    cleanup_portable_temp "$temporary"
    return 1
  fi
  source_dir="$temporary/nvim-linux-${PORTABLE_NVIM_ARCH}"
  if [[ ! -x "$source_dir/bin/nvim" ]]; then
    printf 'The Neovim archive layout was not recognized.\n' >&2
    cleanup_portable_temp "$temporary"
    return 1
  fi

  destination="/usr/local/lib/nvim-bootstrap-$(date +%Y%m%d%H%M%S)-$$"
  link_target="/usr/local/bin/nvim"
  if [[ -e "$link_target" && ! -L "$link_target" ]]; then
    printf 'Refusing to replace unmanaged file %s. Move it aside and rerun bootstrap.\n' "$link_target" >&2
    cleanup_portable_temp "$temporary"
    return 1
  fi
  if [[ -L "$link_target" ]]; then
    case "$(readlink "$link_target")" in
      /usr/local/lib/nvim-bootstrap-*/bin/nvim) ;;
      *)
        printf 'Refusing to replace unmanaged symlink %s. Move it aside and rerun bootstrap.\n' "$link_target" >&2
        cleanup_portable_temp "$temporary"
        return 1
        ;;
    esac
  fi

  $privilege mkdir -p /usr/local/lib /usr/local/bin || {
    cleanup_portable_temp "$temporary"
    return 1
  }
  $privilege cp -R "$source_dir" "$destination" || {
    cleanup_portable_temp "$temporary"
    return 1
  }
  $privilege ln -sfn "$destination/bin/nvim" "$link_target" || {
    cleanup_portable_temp "$temporary"
    return 1
  }
  cleanup_portable_temp "$temporary"
}

run_portable_fallback() {
  local nvim_version="" tree_version="" url="" release_tag=""
  command -v curl >/dev/null 2>&1 || {
    printf 'Portable fallback needs curl to download official release assets.\n' >&2
    return 1
  }
  command -v tar >/dev/null 2>&1 && command -v gzip >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1 || {
    printf 'Portable fallback needs tar, gzip, and unzip before it can unpack release assets.\n' >&2
    return 1
  }
  detect_portable_target || return 1

  nvim_version="$(command_version nvim --version || true)"
  if [[ -z "$nvim_version" ]] || ! version_ge "$nvim_version" "$MIN_NVIM"; then
    install_portable_neovim || printf 'Neovim portable installation failed; continuing with the remaining tools.\n' >&2
  fi

  if ! has_any rg; then
    release_tag="$(github_latest_tag BurntSushi/ripgrep || true)"
    if [[ -n "$release_tag" ]]; then
      url="https://github.com/BurntSushi/ripgrep/releases/download/${release_tag}/ripgrep-${release_tag}-${PORTABLE_RUST_TARGET}.tar.gz"
      install_portable_archive_binary rg "$url" || printf 'ripgrep portable installation failed.\n' >&2
    else
      printf 'Could not resolve the latest official ripgrep release.\n' >&2
    fi
  fi

  tree_version="$(command_version tree-sitter --version || true)"
  if [[ -z "$tree_version" ]] || ! version_ge "$tree_version" "$MIN_TREE_SITTER"; then
    install_portable_archive_binary tree-sitter \
      "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-cli-linux-${PORTABLE_NVIM_ARCH/x86_64/x64}.zip" \
      || printf 'Tree-sitter CLI portable installation failed.\n' >&2
  fi

  if ! has_any fd fdfind; then
    release_tag="$(github_latest_tag sharkdp/fd || true)"
    if [[ -n "$release_tag" ]]; then
      url="https://github.com/sharkdp/fd/releases/download/${release_tag}/fd-${release_tag}-${PORTABLE_RUST_TARGET}.tar.gz"
      install_portable_archive_binary fd "$url" || printf 'fd portable installation failed.\n' >&2
    else
      printf 'Could not resolve the latest official fd release.\n' >&2
    fi
  fi
  export PATH="/usr/local/bin:$PATH"
  hash -r
}

install_tree_sitter_cli() {
  local machine asset url destination temporary temp_root
  command -v curl >/dev/null 2>&1 || return 1
  command -v unzip >/dev/null 2>&1 || return 1

  case "$(uname -m)" in
    x86_64|amd64) machine="x64" ;;
    arm64|aarch64) machine="arm64" ;;
    i386|i686) machine="x86" ;;
    armv7l|armv6l) machine="arm" ;;
    *) printf 'No prebuilt Tree-sitter CLI mapping for architecture %s.\n' "$(uname -m)" >&2; return 1 ;;
  esac

  asset="tree-sitter-cli-${OS_KIND}-${machine}.zip"
  url="https://github.com/tree-sitter/tree-sitter/releases/latest/download/${asset}"
  destination="${HOME}/.local/bin"
  temporary="$(mktemp -d)"
  temp_root="${TMPDIR:-/tmp}"
  temp_root="${temp_root%/}"

  cleanup_tree_sitter_temp() {
    if [[ -n "$temporary" && -d "$temporary" && "$temporary" == "$temp_root/"* ]]; then
      rm -rf -- "$temporary"
    else
      printf 'Refusing to remove unexpected temporary path: %s\n' "$temporary" >&2
    fi
  }
  printf 'Installing the official Tree-sitter CLI release to %s...\n' "$destination"
  mkdir -p "$destination"
  if ! curl -fL "$url" -o "$temporary/$asset"; then
    cleanup_tree_sitter_temp
    return 1
  fi
  if ! unzip -q "$temporary/$asset" -d "$temporary/unpacked"; then
    cleanup_tree_sitter_temp
    return 1
  fi
  local binary
  binary="$(find "$temporary/unpacked" -type f -name tree-sitter -print -quit)"
  if [[ -z "$binary" ]]; then
    printf 'The downloaded archive did not contain the tree-sitter executable.\n' >&2
    cleanup_tree_sitter_temp
    return 1
  fi
  local path_was_configured=0
  [[ ":$PATH:" == *":$destination:"* ]] && path_was_configured=1
  install -m 0755 "$binary" "$destination/tree-sitter"
  cleanup_tree_sitter_temp
  export PATH="$destination:$PATH"
  if [[ "$path_was_configured" -eq 0 ]]; then
    printf 'Add %s to PATH before starting Neovim.\n' "$destination" >&2
  fi
}

missing_required_count() {
  local index count=0
  for ((index = 0; index < ${#REPORT_LEVEL[@]}; index++)); do
    if [[ "${REPORT_LEVEL[$index]}" == "required" && "${REPORT_STATE[$index]}" != "1" ]]; then
      ((count += 1))
    fi
  done
  printf '%s' "$count"
}

missing_host_count() {
  local index count=0
  for ((index = 0; index < ${#REPORT_LEVEL[@]}; index++)); do
    if [[ "${REPORT_LEVEL[$index]}" != "optional" && "${REPORT_STATE[$index]}" != "1" ]]; then
      ((count += 1))
    fi
  done
  printf '%s' "$count"
}

run_editor_bootstrap() {
  printf '\nInstalling Neovim plugins...\n'
  NVIM_BOOTSTRAP=1 nvim --headless "+Lazy! sync" "+qa" || return 1
  printf 'Installing Mason tools and Tree-sitter parsers...\n'
  NVIM_BOOTSTRAP=1 nvim --headless "+BootstrapInstall" "+qa" || return 1
}

detect_platform
printf 'ginko.nvim bootstrap (%s%s)\n' "$OS_KIND" "${DISTRO_ID:+/$DISTRO_ID}"
INSTALL_METHOD="$PACKAGE_MANAGER"

collect_report
show_report

system_install_wanted=0
if [[ "$MODE" == "install" ]]; then
  system_install_wanted=1
elif [[ "$MODE" == "prompt" ]] && { [[ "$(missing_host_count)" -gt 0 ]] || [[ "$WITH_OPTIONAL" -eq 1 ]]; }; then
  system_install_wanted=1
fi

if [[ "$system_install_wanted" -eq 1 && "$OS_KIND" == "unsupported" ]]; then
  printf 'Unsupported operating system: %s. This script will not guess an installation method.\n' "$(uname -s)" >&2
  exit 2
fi
if [[ "$system_install_wanted" -eq 1 && "$OS_KIND" == "macos" && -z "$PACKAGE_MANAGER" ]]; then
  printf 'Homebrew is not installed. Install it from https://brew.sh/, then rerun this script.\n' >&2
  printf 'The script will not install or bootstrap a package manager automatically.\n' >&2
  exit 2
fi
if [[ "$system_install_wanted" -eq 1 && "$OS_KIND" == "macos" ]] && ! xcode-select -p >/dev/null 2>&1; then
  printf 'Xcode Command Line Tools are missing. Run: xcode-select --install\n' >&2
  printf 'Finish that installer, then rerun this script. No package installation was started.\n' >&2
  exit 2
fi
if [[ "$system_install_wanted" -eq 1 && "$OS_KIND" == "linux" && -z "$PACKAGE_MANAGER" ]]; then
  INSTALL_METHOD="portable"
  printf 'No supported package manager matched distro %s.\n' "${DISTRO_ID:-unknown}" >&2
  printf 'Fallback can install official Neovim, ripgrep, Tree-sitter CLI, and fd releases under /usr/local.\n' >&2
  printf 'Git, curl, archive tools, make, a compiler, Node.js, and Python still require system provisioning.\n' >&2
fi

should_install=0
if [[ "$MODE" == "install" ]]; then
  if [[ "$INSTALL_METHOD" == "portable" ]]; then
    printf '\nThe proposed install method is official GitHub binaries under /usr/local.\n'
  else
    printf '\nThe detected package manager is %s.\n' "$PACKAGE_MANAGER"
  fi
  if [[ "$ASSUME_YES" -eq 1 ]] || confirm "Proceed with the displayed system installation method?"; then
    should_install=1
  fi
elif [[ "$system_install_wanted" -eq 1 ]]; then
  if [[ "$INSTALL_METHOD" == "portable" ]]; then
    printf '\nThe proposed install method is official GitHub binaries under /usr/local.\n'
  else
    printf '\nThe detected package manager is %s.\n' "$PACKAGE_MANAGER"
  fi
  confirm "Use this method to install supported dependencies?" && should_install=1
fi

if [[ "$should_install" -eq 1 ]]; then
  if [[ "$INSTALL_METHOD" == "portable" ]]; then
    run_portable_fallback || exit 2
  else
    run_package_manager || exit 2
  fi
  collect_report
  tree_version="$(command_version tree-sitter --version || true)"
  if [[ "$INSTALL_METHOD" != "portable" ]] && { [[ -z "$tree_version" ]] || ! version_ge "$tree_version" "$MIN_TREE_SITTER"; }; then
    install_tree_sitter_cli || {
      printf 'Automatic Tree-sitter CLI installation failed. Use the official release or cargo install --locked tree-sitter-cli.\n' >&2
    }
  fi
  collect_report
  show_report
fi

if [[ "$(missing_required_count)" -gt 0 ]]; then
  printf '\nRequired dependencies are still missing. Neovim bootstrap was not started.\n' >&2
  exit 2
fi

if [[ "$MODE" != "check" && "$SKIP_EDITOR_BOOTSTRAP" -eq 0 ]]; then
  if [[ "$MODE" == "install" ]] || confirm "Install plugins, Mason tools, and Tree-sitter parsers now?"; then
    run_editor_bootstrap || exit 3
  fi
fi

printf '\nBootstrap checks passed. Start Neovim with: nvim\n'
