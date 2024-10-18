#!/bin/bash

set -e

# Import test library bundled with the devcontainer CLI
# See https://github.com/devcontainers/cli/blob/HEAD/docs/features/test.md#dev-container-features-test-lib
source dev-container-features-test-lib

# Feature-specific tests
check "binaryExists" bash -c "ls /usr/local/bin/dragonfly"
check "specificVersion" bash -c "dragonfly --version | grep -qE '1\.24\.0'"

# Report results
reportResults
