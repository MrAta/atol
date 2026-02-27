#!/usr/bin/env bash
# atol installer
# curl -fsSL https://raw.githubusercontent.com/ata/atol/main/install.sh | bash

set -euo pipefail

REPO="MrAta/atol"
BIN_DIR="${HOME}/.local/bin"
INSTALL_PATH="${BIN_DIR}/atol"
RAW_URL="https://raw.githubusercontent.com/${REPO}/main/atol"

WHY_FUNCTION='
# atol: why — explain last command failure
why() {
  local exit_code=$?
  local last_cmd
  last_cmd=$(fc -ln -1 2>/dev/null | sed '"'"'s/^ *//'"'"')
  printf '"'"'%s\n'"'"' "$last_cmd" | atol --no-tools "Exit code was $exit_code. Why did this fail and how do I fix it?"
}'

WHY_MARKER="# atol: why — explain last command failure"

print_step() { printf '  \033[1;34m→\033[0m %s\n' "$1"; }
print_ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$1"; }
print_warn() { printf '  \033[1;33m!\033[0m %s\n' "$1"; }
print_err()  { printf '  \033[1;31m✗\033[0m %s\n' "$1" >&2; }

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------

if ! command -v curl &>/dev/null; then
  print_err "curl is required but not found"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  print_warn "claude CLI not found — install it from https://claude.ai/code"
  print_warn "atol will not work until claude is installed"
fi

# ---------------------------------------------------------------------------
# Download atol
# ---------------------------------------------------------------------------

print_step "Installing atol to ${INSTALL_PATH}"
mkdir -p "$BIN_DIR"
curl -fsSL "$RAW_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
print_ok "atol installed"

# ---------------------------------------------------------------------------
# PATH setup
# ---------------------------------------------------------------------------

if ! printf '%s' "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
  print_warn "${BIN_DIR} is not in your PATH"

  # Detect shell rc file
  local_rc=""
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL:-}" == *zsh* ]]; then
    local_rc="${HOME}/.zshrc"
  elif [[ -n "${BASH_VERSION:-}" ]] || [[ "${SHELL:-}" == *bash* ]]; then
    local_rc="${HOME}/.bashrc"
  fi

  if [[ -n "$local_rc" ]]; then
    printf '  Add %s to PATH? [Y/n] ' "$BIN_DIR"
    read -r answer </dev/tty || answer="y"
    case "${answer:-y}" in
      [Yy]|"")
        printf '\n# atol\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >> "$local_rc"
        print_ok "Added to ${local_rc} — restart your shell or run: source ${local_rc}"
        ;;
      *)
        print_warn "Skipped — add this to your shell rc manually:"
        printf '    export PATH="%s:$PATH"\n' "$BIN_DIR"
        ;;
    esac
  else
    print_warn "Add this to your shell rc manually:"
    printf '    export PATH="%s:$PATH"\n' "$BIN_DIR"
  fi
else
  print_ok "${BIN_DIR} already in PATH"
fi

# ---------------------------------------------------------------------------
# Inject `why` shell function
# ---------------------------------------------------------------------------

# Detect rc file
rc_file=""
if [[ -f "${HOME}/.zshrc" ]]; then
  rc_file="${HOME}/.zshrc"
elif [[ -f "${HOME}/.bashrc" ]]; then
  rc_file="${HOME}/.bashrc"
fi

if [[ -n "$rc_file" ]]; then
  if grep -qF "$WHY_MARKER" "$rc_file" 2>/dev/null; then
    print_ok "'why' function already present in ${rc_file}"
  else
    printf '  Add the '"'"'why'"'"' shell function to %s? [Y/n] ' "$rc_file"
    read -r answer </dev/tty || answer="y"
    case "${answer:-y}" in
      [Yy]|"")
        printf '\n%s\n' "$WHY_FUNCTION" >> "$rc_file"
        print_ok "Added 'why' to ${rc_file}"
        ;;
      *)
        print_warn "Skipped — add the following to your shell rc manually:"
        printf '%s\n' "$WHY_FUNCTION"
        ;;
    esac
  fi
else
  print_warn "Could not find .zshrc or .bashrc — add 'why' manually:"
  printf '%s\n' "$WHY_FUNCTION"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

printf '\n'
print_ok "Done! atol $(${INSTALL_PATH} --version 2>/dev/null || echo '0.1.0') ready."
printf '\n'
printf '  Try:\n'
printf '    atol "what does CUDA_VISIBLE_DEVICES do"\n'
printf '    atol logs <pod-name>\n'
printf '    false; why\n'
printf '\n'
printf '  Restart your shell (or: source %s) to activate changes.\n' "${rc_file:-your shell rc}"
printf '\n'
