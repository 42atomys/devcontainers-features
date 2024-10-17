#!/bin/bash

set -e

# Import test library bundled with the devcontainer CLI
# See https://github.com/devcontainers/cli/blob/HEAD/docs/features/test.md#dev-container-features-test-lib
source dev-container-features-test-lib

# Feature-specific tests
check "specificVersion" bash -c "meilisearch --version | grep -qE '1\.10\.2'"

# Report results
reportResults
