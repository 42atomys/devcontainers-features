#!/bin/bash

set -e

# Import test library bundled with the devcontainer CLI
# See https://github.com/devcontainers/cli/blob/HEAD/docs/features/test.md#dev-container-features-test-lib
source dev-container-features-test-lib

# Feature-specific tests
check "configurationExists" bash -c "ls /usr/local/share/meilisearch-server-init.sh"
check "specificVersion" meilisearch --version | grep -qE '^v1\.10\.3?$'

# Report results
reportResults
