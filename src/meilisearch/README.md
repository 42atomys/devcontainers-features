# Dev Container Features: Atomys Collection

> This repo provides a starting point and example for creating your own custom [dev container Features](https://containers.dev/implementors/features/), hosted for free on GitHub Container Registry. The example in this repository follows the [dev container Feature distribution specification](https://containers.dev/implementors/features-distribution/).

> To provide feedback to the specification, please leave a comment [on spec issue #70](https://github.com/devcontainers/spec/issues/70). For more broad feedback regarding dev container Features, please see [spec issue #61](https://github.com/devcontainers/spec/issues/61).

## Example Contents

This repository contains a _collection_ of Features. These Features serve as simple feature implementations. Each sub-section below shows a sample `devcontainer.json` alongside example usage of the Feature.

### `meilisearch`

This feature installs Meilisearch in your development container. Meilisearch is an open-source search engine that is easy to use and fast.

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/42atomys/devcontainers-features/meilisearch:1": {
            "version": "v1.10.3"
        }
    }
}
```

If no version is specified, the latest version will be installed by default.

## Options

### `meilisearch`

| Options Id | Description | Type | Default Value |
|------------|-------------|------|---------------|
| version    | The version of Meilisearch to install. | string | latest |

## Mounts

The feature mounts a volume for Meilisearch data: `/var/lib/meilisearch/data`

## Additional Information

For more details, refer to the [devcontainer Feature specification](https://containers.dev/implementors/features/#devcontainer-feature-json-properties).
