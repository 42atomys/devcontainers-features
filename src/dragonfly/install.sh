#!/bin/sh
set -e

echo "Activating feature 'dragonfly'"

# Accept VERSION as an environment variable or first argument
VERSION=${VERSION:-${1:-latest}}
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
EXTRA_ARGUMENTS=${EXTRAARGUMENTS:-""}

echo "Version of Dragonfly to install: $VERSION"

# GitHub API address for Dragonfly releases
GITHUB_API='https://api.github.com/repos/dragonflydb/dragonfly/releases'

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
  USERNAME=""
  for CURRENT_USER in vscode node codespace $(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd); do
    if id -u ${CURRENT_USER} > /dev/null 2>&1; then
      USERNAME=${CURRENT_USER}
      break
    fi
  done
  if [ "${USERNAME}" = "" ]; then
    USERNAME=root
  fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
  USERNAME=root
fi

# Install necessary dependencies
install_dependencies() {
  if [ "$(id -u)" -ne 0 ]; then
    SUDO='sudo'
  else
    SUDO=''
  fi

  if command -v curl >/dev/null && command -v jq >/dev/null; then
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    UPDATE_CMD="$SUDO apt-get update -y"
    INSTALL_CMD="$SUDO apt-get install -y"
  elif command -v yum >/dev/null 2>&1; then
    UPDATE_CMD="$SUDO yum check-update -y || true"
    INSTALL_CMD="$SUDO yum install -y"
  elif command -v dnf >/dev/null 2>&1; then
    UPDATE_CMD="$SUDO dnf check-update -y || true"
    INSTALL_CMD="$SUDO dnf install -y"
  elif command -v apk >/dev/null 2>&1; then
    UPDATE_CMD="$SUDO apk update"
    INSTALL_CMD="$SUDO apk add"
  else
    echo "Unsupported package manager. Please install 'curl' and 'jq' manually."
    exit 1
  fi

  echo "Updating package lists..."
  eval "$UPDATE_CMD"

  if ! command -v curl >/dev/null 2>&1; then
    echo "Installing 'curl'..."
    eval "$INSTALL_CMD curl"
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "Installing 'jq'..."
    eval "$INSTALL_CMD jq"
  fi
}

# Detect OS and architecture and download appropriate Dragonfly binary
get_specific_version() {
  OS=$(uname -s)
  ARCH=$(uname -m)

  if [ "$OS" != "Linux" ]; then
    echo "This script only supports Linux."
    exit 1
  fi

  case "$ARCH" in
    x86_64)
      asset_name="dragonfly-x86_64.tar.gz"
      arch="x86_64"
      ;;
    aarch64 | arm64)
      asset_name="dragonfly-aarch64.tar.gz"
      arch="aarch64"
      ;;
    *)
      echo "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  echo "Fetching release information for version $VERSION"
  if [ "$VERSION" = "latest" ]; then
    # Fetch latest release information
    release_data=$(curl -s "$GITHUB_API/latest")
  else
    # Fetch specific release information
    release_data=$(curl -s "$GITHUB_API/tags/v$VERSION")
  fi

  # Find the appropriate binary for the architecture
  download_url=$(echo "$release_data" | grep -o '"browser_download_url": *"[^"]*"' | grep "$asset_name" | sed -E 's/.*"browser_download_url": *"([^"]*)".*/\1/')

  if [ -z "$download_url" ]; then
    echo "No binary available for architecture $ARCH."
    exit 1
  fi

  echo "Downloading Dragonfly version $VERSION for $ARCH"
  curl -L -o dragonfly.tar.gz "$download_url"
  tar -xzf dragonfly.tar.gz
  rm dragonfly.tar.gz
}

# Set up Dragonfly
setup_dragonfly() {
    tee /usr/local/share/dragonfly-server-init.sh << 'EOF'
#!/bin/sh
set -e
$SUDO /usr/local/bin/dragonfly --logtostderr --dir /var/lib/dragonfly/data $EXTRA_ARGUMENTS
set +e
# Execute whatever commands were passed in (if any). This allows us
# to set this script to ENTRYPOINT while still executing the default CMD.
exec "$@"
EOF
  # Move the binary to the bin directory
  mv dragonfly-$arch /usr/local/bin/dragonfly
  chmod +x /usr/local/bin/dragonfly

  # Create dragonfly folders
  mkdir -p /var/lib/dragonfly && chown ${USERNAME}:root /var/lib/dragonfly

  # Create the entrypoint script
  chmod +x /usr/local/share/dragonfly-server-init.sh \
    && chown ${USERNAME}:root /usr/local/share/dragonfly-server-init.sh
}

# Main function to install Dragonfly
main() {
  install_dependencies

  if [ "$VERSION" = "latest" ]; then
    echo "Fetching the latest version of Dragonfly..."
  fi

  get_specific_version
  setup_dragonfly

  echo "Dragonfly $VERSION has been installed successfully."
}

main
