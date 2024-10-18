#!/bin/bash

set -e

# Import test library bundled with the devcontainer CLI
# See https://github.com/devcontainers/cli/blob/HEAD/docs/features/test.md#dev-container-features-test-lib
source dev-container-features-test-lib

# Feature-specific tests
check "serverBinaryExists" bash -c "ls /usr/local/bin/minio"
check "clientBinaryExists" bash -c "ls /usr/local/bin/mc"
check "latestVersion" minio --version

check "serverIsRunning" bash -c "mc mb --ignore-existing minio/minio && mc ls minio/minio"

# Report results
reportResults
