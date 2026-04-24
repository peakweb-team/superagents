# Devcontainer Rebuild Runbook

This runbook captures common high-signal fixes for flaky devcontainer rebuilds in this repository.

## 1) APT Sandbox Keyring Failure (Highest Priority)

If Docker build fails during `apt-get update` with errors like:

- `At least one invalid signature was encountered`
- `E: The repository '...' is not signed`

...across all Debian repos at once, treat it as an APT sandbox keyring-access issue first.

Required Dockerfile pattern:

```Dockerfile
RUN apt-get -o APT::Sandbox::User=root update && apt-get install -y ...
```

Quick triage:

- If all repos fail at once and manual `gpgv` validation succeeds, suspect APT sandbox keyring access.
- If only one repo fails, suspect stale/missing key material for that repo.

## 2) Keep Node Base Image Current

- Prefer `node:24` (or current LTS major) over older majors like `node:20`.
- Pin to a major tag (for example `node:24`), not an immutable image SHA, so rebuilds can pull keyring/security refreshes.

## 3) Prefer `desktop-linux` Buildx Builder

For local devcontainer rebuilds, prefer the local daemon-backed builder:

```bash
docker buildx use desktop-linux
```

Why:

- The `multiplatform` (`docker-container` driver) builder runs in its own network namespace and can surface TLS/auth timeout errors to Docker Hub during rebuilds.
- `desktop-linux` (`docker` driver) uses the local daemon directly and is typically more reliable for this workflow.

## 4) Disk Hygiene (Periodic)

When rebuilds begin failing randomly, check Docker VM disk pressure first:

```bash
docker run --rm alpine df -h /
```

If space is constrained, clean up:

```bash
docker system prune -f
docker builder prune -f
```

If still full and `multiplatform` buildkit state is bloated:

```bash
docker rm -f buildx_buildkit_multiplatform0
docker volume rm buildx_buildkit_multiplatform0_state
```

Notes:

- The `buildx_buildkit_multiplatform0_state` volume can grow to multiple GB.
- 100% Docker VM disk utilization often presents as intermittent, misleading build failures.
