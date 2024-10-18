#!/bin/sh
set -e

echo "Activating feature 'meilisearch'"

# Accept VERSION as an environment variable or first argument
VERSION=${VERSION:-${1:-latest}}
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

echo "Version of MeiliSearch to install: $VERSION"

# GitHub API address
GITHUB_API='https://api.github.com/repos/meilisearch/meilisearch/releases'

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
# Installs curl and jq using the appropriate package manager
# if they are not present. The function will exit with an error
# if the package manager is unsupported.
install_dependencies() {
  # Check if the script is running as root or with sudo
  if [ "$(id -u)" -ne 0 ]; then
    SUDO='sudo'
  else
    SUDO=''
  fi

  # Check if curl and jq are installed and if not, install them
  if command -v curl >/dev/null && command -v jq >/dev/null; then
    return
  fi

  # Detect package manager and install missing packages
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

  # Update package lists
  echo "Updating package lists..."
  eval "$UPDATE_CMD"

  # Install curl if not installed
  if ! command -v curl >/dev/null 2>&1; then
    echo "Installing 'curl'..."
    eval "$INSTALL_CMD curl"
  fi

  # Install jq if not installed
  if ! command -v jq >/dev/null 2>&1; then
    echo "Installing 'jq'..."
    eval "$INSTALL_CMD jq"
  fi
}

# Fetches and downloads a specific version of MeiliSearch based on the system architecture.
#
# This function checks the operating system and architecture of the system to determine if
# it is supported. It specifically supports Linux systems with 'amd64' or 'aarch64' architectures.
# It then retrieves the release data for the specified version of MeiliSearch from GitHub and finds
# the appropriate binary download URL for the architecture. If a suitable binary is found, it downloads
# and makes it executable. If the architecture or version is unsupported, the function exits with an error.
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
      ARCH="amd64"
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
  release_data=$(curl -s "$GITHUB_API/tags/v$VERSION")

  # Find the appropriate binary for the architecture
  asset_name="meilisearch-linux-$ARCH"
  download_url=$(echo "$release_data" | grep -o '"browser_download_url": *"[^"]*"' | grep "$asset_name" | sed -E 's/.*"browser_download_url": *"([^"]*)".*/\1/')
  if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
    echo "No binary available for architecture $ARCH."
    exit 1
  fi

  echo "Downloading MeiliSearch version $VERSION for $ARCH"
  curl -L -o meilisearch "$download_url"
  chmod +x meilisearch
}

# Create an entrypoint script that starts MeiliSearch as the correct user.
# We use 'set -e' to ensure that if MeiliSearch fails to start, the container
# will exit, and 'set +e' to allow the execution of user-provided commands.
setup_meilisearch() {
  tee /usr/local/share/meilisearch-server-init.sh << 'EOF'
#!/bin/sh
set -e
$SUDO /usr/local/bin/meilisearch --env development --db-path /var/lib/meilisearch/data
set +e
# Execute whatever commands were passed in (if any). This allows us
# to set this script to ENTRYPOINT while still executing the default CMD.
exec "$@"
EOF

  # Move the binary to the bin directory
  mv meilisearch /usr/local/bin/meilisearch
  chmod +x /usr/local/bin/meilisearch

  # Create meilisearch folders
  mkdir -p /var/lib/meilisearch && chown ${USERNAME}:root /var/lib/meilisearch

  # Create the entrypoint script
  chmod +x /usr/local/share/meilisearch-server-init.sh \
    && chown ${USERNAME}:root /usr/local/share/meilisearch-server-init.sh
}

# Install MeiliSearch with the specified version.
#
# This function installs the dependencies, downloads and installs MeiliSearch,
# and sets up the entrypoint script.
main() {
  # Install dependencies if not present
  install_dependencies

  if [ "$VERSION" = "latest" ]; then
    # Install the latest version using the official script
    echo "Installing the latest version of MeiliSearch..."
    curl -L https://install.meilisearch.com | sh
  else
    # Install the specified version
    get_specific_version
  fi

  setup_meilisearch

  echo "MeiliSearch $VERSION has been installed successfully."
}

main
