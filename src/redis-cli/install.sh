#!/bin/sh
set -e

echo "Activating feature 'redis-cli'"

# Accept VERSION as an environment variable or first argument
VERSION=${VERSION:-${1:-latest}}
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

echo "Version of redis-cli to install: $VERSION"

# GitHub API address for Redis releases
GITHUB_API='https://api.github.com/repos/redis/redis/releases'

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

# Function to install dependencies if they are missing
install_dependencies() {
  # Check if the script is running as root or with sudo
  if [ "$(id -u)" -ne 0 ]; then
    SUDO='sudo'
  else
    SUDO=''
  fi

  # Check if curl and build tools are installed, and install them if necessary
  if command -v curl >/dev/null && command -v gcc >/dev/null && command -v make >/dev/null; then
    return
  fi

  # Detect package manager and install missing packages
  if command -v apt-get >/dev/null 2>&1; then
    UPDATE_CMD="$SUDO apt-get update -y"
    INSTALL_CMD="$SUDO apt-get install -y build-essential curl sudo"
  elif command -v yum >/dev/null 2>&1; then
    UPDATE_CMD="$SUDO yum check-update -y || true"
    INSTALL_CMD="$SUDO yum install -y gcc make curl sudo"
  elif command -v dnf >/dev/null 2>&1; then
    UPDATE_CMD="$SUDO dnf check-update -y || true"
    INSTALL_CMD="$SUDO dnf install -y gcc make curl sudo"
  elif command -v apk >/dev/null 2>&1; then
    UPDATE_CMD="$SUDO apk update"
    INSTALL_CMD="$SUDO apk add --no-cache build-base curl sudo"
  else
    echo "Unsupported package manager. Please install 'gcc', 'make', 'curl' and 'sudo' manually."
    exit 1
  fi

  # Update package lists
  echo "Updating package lists..."
  eval "$UPDATE_CMD"

  # Install missing packages
  echo "Installing build dependencies (curl, gcc, make)..."
  eval "$INSTALL_CMD"
}

# Fetches and downloads a specific version of redis-cli based on the system architecture
get_specific_version() {
  # Detect system architecture
  OS=$(uname -s)
  ARCH=$(uname -m)

  if [ "$OS" != "Linux" ]; then
    echo "This script only supports Linux."
    exit 1
  fi

  case "$ARCH" in
    x86_64)
      ARCH="x86_64"
      ;;
    aarch64 | arm64)
      ARCH="aarch64"
      ;;
    *)
      echo "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  echo "Fetching release information for version $VERSION"
  
  if [ "$VERSION" = "latest" ]; then
    # Get latest release information from GitHub
    release_data=$(curl -s "$GITHUB_API/latest")
  else
    # Fetch a specific release by tag/version
    release_data=$(curl -s "$GITHUB_API/tags/$VERSION")
  fi

  # Extract the tarball URL for source code
  tarball_url=$(echo "$release_data" | grep -o '"tarball_url": *"[^"]*"' | grep "$asset_name" | sed -E 's/.*"tarball_url": *"([^"]*)".*/\1/')

  if [ -z "$tarball_url" ] || [ "$tarball_url" = "null" ]; then
    echo "No tarball available for version $VERSION."
    exit 1
  fi

  echo "Downloading and extracting Redis source for version $VERSION..."
  curl -L -o redis.tar.gz "$tarball_url"
  mkdir redis-source
  tar -xzf redis.tar.gz -C redis-source --strip-components=1
  cd redis-source

  echo "Building redis-cli..."
  make redis-cli

  echo "Moving redis-cli to /usr/local/bin..."
  sudo mv src/redis-cli /usr/local/bin/redis-cli

  echo "Cleaning up temporary files..."
  cd ..
  rm -rf redis-source redis.tar.gz
}

# Install redis-cli with the specified version
main() {
  # Install dependencies if not present
  install_dependencies

  # Install the specific or latest version
  get_specific_version

  echo "redis-cli $VERSION has been installed successfully."
}

main
