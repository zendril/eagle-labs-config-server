# Chuck Artifact Bundle

This directory contains the *actual* logic and binaries for the Chuck tool.
In the "Option C" Dynamic Bootstrap model, these files are packaged into a `.tar.gz` and served by the Policy/Config Server.

## Contents

- `chuck.sh`: The tool binary (simulated).
- `install.sh`: The *inner* installer that places files.
- `entrypoint.sh`: The *real* runtime governance logic.
- `check-version.sh`: Telemetry script.

## Packaging

To create the bundle that the Policy Server should serve:

```bash
tar -czf chuck-bundle-1.0.0.tar.gz .
```

## Config Server Integration Instructions

The `eagle-labs-config-server` needs to expose an endpoint that serves this bundle.

1.  **Endpoint Definition:**
    Create a route like `GET /policy/chuck/{version}`.

2.  **Logic:**
    - Receive the request.
    - Validate headers (e.g., `X-Eagle-Token` if applicable).
    - **Development/MVP:** Stream the `chuck-bundle-1.0.0.tar.gz` file directly to the response.
    - **Production (Architecture Note):**
        > **Note:** Ideally, the Config Server should *not* stream large binaries.
        > It should instead generate a short-lived **S3 Presigned URL** (or Azure Blob SAS Token) for the artifact and return a `302 Redirect` to that URL.
        > This offloads the bandwidth to the cloud storage provider.

3.  **Dynamic Configuration:**
    If you need to inject dynamic configuration (e.g., specific environment variables for this specific user request), you have two options:
    - **A:** Generate a `config.env` file on the fly, add it to the tarball in memory, and then stream it.
    - **B:** (Simpler) Return the bundle as is, but include HTTP headers or a separate lightweight JSON response that the bootstrap `install.sh` can read (requires modifying the bootstrap script to handle this). For now, assume Option A or static bundles.
