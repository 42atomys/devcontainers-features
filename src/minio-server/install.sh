#!/bin/sh
set -e

echo "Activating feature 'minio-server'"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
EXTRA_ARGUMENTS=${EXTRAARGUMENTS:-""}

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
  if command -v curl >/dev/null; then
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
    echo "Unsupported package manager. Please install 'curl' manually."
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
}

# setup_minio
#
# This function sets up the entrypoint script for the Minio Server service.
#
# It creates the entrypoint script at /usr/local/share/minio-server-init.sh and
# sets it to be executable. The entrypoint script is used as the ENTRYPOINT for
# the Minio Server service and starts the Minio Server process.
#
# The function also creates the Minio Server folders and sets their ownership
# to the specified user.
setup_minio() {
  tee /usr/local/share/minio-server-init.sh << 'EOF'
#!/bin/sh
set -e
$SUDO /usr/local/bin/minio server /var/lib/minio/data $EXTRA_ARGUMENTS
set +e
# Execute whatever commands were passed in (if any). This allows us
# to set this script to ENTRYPOINT while still executing the default CMD.
exec "$@"
EOF
  # Create minio folders
  mkdir -p /var/lib/minio && chown ${USERNAME}:root /var/lib/minio

  # Create the entrypoint script
  chmod +x /usr/local/share/minio-server-init.sh \
    && chown ${USERNAME}:root /usr/local/share/minio-server-init.sh
}

# Download minio server and client binaries from official repository
# and install them in /usr/local/bin
download_binaries() {
  curl -L https://dl.min.io/server/minio/release/linux-amd64/minio -o minio
  chmod +x minio
  mv minio /usr/local/bin/minio

  curl -L https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
  chmod +x mc
  mv mc /usr/local/bin/mc
}

main() {
  install_dependencies
  download_binaries
  setup_minio

  echo "Minio Server and Client has been installed successfully."
}

main

