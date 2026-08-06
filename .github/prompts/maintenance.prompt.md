---
description: "Update the Ubuntu base image digest, pinned APT package versions, AWS CLI version, NVIDIA CUDA versions, and R version in the Dockerfile and open a pull request"
tools:
  [
    execute/getTerminalOutput,
    execute/runInTerminal,
    read/readFile,
    vscodeGeneral/usages,
    edit/editFiles,
    search,
  ]
---

# Maintenance

Perform maintenance on the `Dockerfile`. Update the base image digest, pinned APT package versions, AWS CLI version, NVIDIA CUDA versions, and R version together, and open a single pull request. Read all current values from the `Dockerfile`; do not assume specific versions or package sets.

## Objective

In one pull request, for all components already declared in the `Dockerfile`:

1. Update the pinned base image digest to the latest published digest for the image and tag in the `FROM` line (for `linux/amd64`).
2. Refresh the pinned APT package versions to the latest available for that base image, preserving the current package list.
3. Update the AWS CLI version to the latest release.
4. Update the NVIDIA CUDA package versions (`cuda-cudart` and `cuda-compat`) to the latest available.
5. Update the R version (`r-base`) to the latest available from the CRAN repository.

Do not assume specific versions. Always read the current values from the `Dockerfile`.

## Required Outcome

1. Create a single maintenance branch.
2. Update the Ubuntu base image digest in the `FROM` line.
3. Update the pinned APT package versions.
4. Update `AWS_CLI_VERSION`.
5. Update `NVIDIA_CUDA_CUDART_VERSION` and `NVIDIA_CUDA_COMPAT_VERSION`.
6. Update `R_VERSION`.
7. Commit all changes using Conventional Commits.
8. Push the branch and open a pull request with a clear title and description.

## Execution Steps

### 1. Create a maintenance branch

```bash
git checkout -b "chore/maintenance-dockerfile-$(date +%Y%m%d-%H%M%S)"
```

### 2. Update the base image digest

- Read the base image reference (`<image>:<tag>`) from the `FROM` line in `Dockerfile`.
- Pull that exact image for `linux/amd64`.

```bash
IMAGE="$(grep -oP '(?<=^FROM )[^@[:space:]]+' Dockerfile)"
docker pull --platform linux/amd64 "$IMAGE"
```

- Retrieve the current repository digest.

```bash
docker image inspect --format='{{ index .RepoDigests 0 }}' "$IMAGE"
```

- Update the `@sha256:...` digest on the `FROM` line to the new value, keeping the image and tag unchanged.

### 3. Update the pinned APT package versions

- Read the list of pinned packages from the `apt-get install` block in `Dockerfile`.
- Start a temporary container using the same base image and check the candidate versions for those packages.

```bash
docker run --rm --platform linux/amd64 "$IMAGE" \
  bash -c "apt-get update -qq && apt-cache policy <packages-from-dockerfile>"
```

- Update each pinned version in `Dockerfile` to the reported candidate, preserving every package currently listed.

### 4. Update the AWS CLI version

- Check the latest release from the [AWS CLI v2 changelog](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst).
- Update `AWS_CLI_VERSION` in the `ENV` block to the latest version number.

### 5. Update the NVIDIA CUDA versions

- Run a temporary container to add the NVIDIA CUDA repository and check the latest available versions.

```bash
docker run --rm --platform linux/amd64 "$IMAGE" bash -c "
  apt-get update -qq && apt-get install -y curl gpg &&
  curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub | gpg --dearmor -o /etc/apt/keyrings/nvidia.gpg &&
  echo 'deb [signed-by=/etc/apt/keyrings/nvidia.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64 /' > /etc/apt/sources.list.d/cuda.list &&
  apt-get update -qq &&
  apt-cache policy <cuda-cudart-package> <cuda-compat-package>
"
```

- Read the current CUDA package names (e.g. `cuda-cudart-13-1`, `cuda-compat-13-1`) from the `Dockerfile` — do not assume a specific version.
- Update `NVIDIA_CUDA_CUDART_VERSION` and `NVIDIA_CUDA_COMPAT_VERSION` in the `ENV` block to the new candidate versions.
- If the CUDA major/minor version has changed, also update `CUDA_VERSION` and the package name suffixes (e.g. `cuda-cudart-13-1`) throughout the Dockerfile.

### 6. Update the R version

- Run a temporary container to add the CRAN repository and check the latest available `r-base` version.

```bash
docker run --rm --platform linux/amd64 "$IMAGE" bash -c "
  apt-get update -qq && apt-get install -y curl gpg &&
  curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | gpg --dearmor -o /etc/apt/keyrings/marutter_pubkey.gpg &&
  echo 'deb [signed-by=/etc/apt/keyrings/marutter_pubkey.gpg] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/' > /etc/apt/sources.list.d/cran.list &&
  apt-get update -qq &&
  apt-cache policy r-base
"
```

- Update `R_VERSION` in the `ENV` block to the new candidate version.

### 7. Update the container structure tests

- Read the current version assertions in `test/container-structure-test.yml`.
- For every version that changed in the `Dockerfile`, update the corresponding `expectedOutput` in the test file:
  - `aws --version` → match the new `AWS_CLI_VERSION`
  - `R --version` → match the new `R_VERSION`
- Do not add or remove test cases; only update the version strings for packages that actually changed.

### 8. Confirm changes are scoped correctly

Confirm that the `Dockerfile` still lists the same packages and the same base image and tag as before — only the digest, ENV versions, and package version pins should differ. Confirm that `test/container-structure-test.yml` reflects the same versions as the updated `Dockerfile`.

### 9. Commit the changes

Commit all changes to `Dockerfile` and `test/container-structure-test.yml` together using [Conventional Commits](https://www.conventionalcommits.org/) (`build` type).

### 10. Push the branch and open the pull request

- The `git commit`, `git push`, and `gh` steps need local Git/GitHub credentials and network access. When the terminal is sandboxed these are hidden, so run these steps with the required access rather than stopping. A sandboxed `gh auth status` may report "not logged in" even when authenticated; do not treat that as a blocker.
- Set an explicit PR title using a [Conventional Commits](https://www.conventionalcommits.org/) `build:` summary (for example, `build: update base image digest and software versions`). Do not use `gh pr create --fill`.
- Write the PR description to a temporary file and pass it with `--body-file` to avoid shell-escaping issues. Wrap all SHA values in backticks. Use this structure:

```markdown
## Summary

Updates the `Dockerfile` build dependencies.

### Base image

- `<image>:<tag>` digest: `sha256:<old>` -> `sha256:<new>` (image and tag unchanged)

### APT packages

Include this section only when one or more package versions changed.

| Package | Before  | After   |
| ------- | ------- | ------- |
| curl    | `<old>` | `<new>` |

If no APT package versions changed, omit the `### APT packages` section and add a line in `## Summary`: `APT package versions already up to date.`

### AWS CLI

- `AWS_CLI_VERSION`: `<old>` -> `<new>`

If unchanged, omit this section.

### NVIDIA CUDA

| Variable                     | Before  | After   |
| ---------------------------- | ------- | ------- |
| `NVIDIA_CUDA_CUDART_VERSION` | `<old>` | `<new>` |
| `NVIDIA_CUDA_COMPAT_VERSION` | `<old>` | `<new>` |

If unchanged, omit this section.

### R

- `R_VERSION`: `<old>` -> `<new>`

If unchanged, omit this section.

### Tests

Updated `test/container-structure-test.yml` to reflect the new versions for: <list changed components, e.g. AWS CLI, R>.

If no test values changed, omit the `### Tests` section.

Note any components that could not be upgraded and why.

Building and testing is handled by CI/CD.
```

- Create the pull request:

```bash
gh pr create --base main --head <branch> --title "<title>" --body-file <body-file>
```

- Report the URL of the created pull request.

Building and testing the image is handled by CI/CD, so it is not part of this runbook.

## Guardrails

- Keep the base image repository and tag unchanged; only update the digest.
- Keep platform assumption aligned to `linux/amd64`.
- Do not add or remove packages. Update exactly the packages already pinned in the `Dockerfile`.
- Keep all package installs pinned to explicit versions.
- Keep `test/container-structure-test.yml` in sync with the versions in `Dockerfile`; update test assertions for every version that changes.
- Deliver all updates in the same branch and pull request.
- Use [Conventional Commits](https://www.conventionalcommits.org/) for both the commit message and the PR title (`build` type).
