#!/usr/bin/env bash
#
# Installs the itops CLI (scripts/linux or scripts/macos toolkit, detected
# automatically) for the current user. No sudo required: installs into
# ~/.itops and symlinks into ~/.local/bin.
#
#   curl -fsSL https://raw.githubusercontent.com/xr3ferenc3/it-support-ops/main/install.sh | bash
#
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/xr3ferenc3/it-support-ops/main"
INSTALL_DIR="${ITOPS_INSTALL_DIR:-$HOME/.itops}"
BIN_DIR="${ITOPS_BIN_DIR:-$HOME/.local/bin}"

case "$(uname -s)" in
    Darwin)
        PLATFORM_DIR="macos"
        ;;
    Linux)
        PLATFORM_DIR="linux"
        ;;
    *)
        echo "itops: unsupported platform '$(uname -s)'. This installer supports" >&2
        echo "Linux and macOS. Windows users should use the ITSupportOps PowerShell" >&2
        echo "module instead — see module/ITSupportOps in the repository." >&2
        exit 1
        ;;
esac

SCRIPTS=(
    system-health-report.sh
    network-diagnostics.sh
    disk-health-report.sh
    log-summary.sh
    connectivity-suite.sh
)

echo "Detected platform: $(uname -s) — installing $PLATFORM_DIR toolkit"
echo "Installing itops to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR/scripts" "$INSTALL_DIR/integrations" "$BIN_DIR"

for s in "${SCRIPTS[@]}"; do
    curl -fsSL "$REPO_RAW/scripts/$PLATFORM_DIR/$s" -o "$INSTALL_DIR/scripts/$s"
    chmod +x "$INSTALL_DIR/scripts/$s"
done

curl -fsSL "$REPO_RAW/integrations/send-to-freshservice.sh" -o "$INSTALL_DIR/integrations/send-to-freshservice.sh"
chmod +x "$INSTALL_DIR/integrations/send-to-freshservice.sh"

curl -fsSL "$REPO_RAW/cli/itops" -o "$INSTALL_DIR/itops"
chmod +x "$INSTALL_DIR/itops"
ln -sf "$INSTALL_DIR/itops" "$BIN_DIR/itops"

echo "Installed: $BIN_DIR/itops -> $INSTALL_DIR/itops"
echo

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "NOTE: $BIN_DIR is not on your PATH yet. Add this to your shell profile"
    echo "(~/.bashrc, ~/.zshrc, etc.) and restart your shell:"
    echo
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo
fi

echo "Run 'itops help' to get started."