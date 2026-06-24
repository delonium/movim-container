<div align="center">
    <h1>Movim Container</h1>
    <h4>An officially endorsed image maintained by the community.</h4>
    <a href="https://github.com/delonium/movim-container/actions/workflows/release.yml">
        <img src="https://github.com/delonium/movim-container/actions/workflows/release.yml/badge.svg" >
    </a>
</div>

### Unprivileged

The container runs as the `www-data` user.

The webserver will listen on HTTP port `8080` when running in production mode and on HTTPS port `8443` when running in testing mode.

### Compose File

See the [compose.yaml](compose.yaml) file for a minimal example with a Postgres database.

### Testing

> [!WARNING]
> Movim requires a real domain name with TLS to function fully. Testing mode may have degraded behavior, but it will work enough to do most tasks and to get a feel of Movim.

Using the `compose.yaml` file without changes will launch Movim in testing mode, which allows trying Movim locally on your machine. You can launch the compose file with [Podman (main website)](https://podman.io/). Podman is a FOSS alternative to Docker that is available on all the main distributions.

Install `podman` and `podman-compose`, then run:

    podman compose up -d

After a few moments, you can access Movim in your browser at the following URL:

    https://127.0.0.1:8443

Note that testing mode uses a self-signed certificate, so you need to accept the security warning in your browser before opening the url.

### Configuration

You can configure the container by setting the environment variables found in the [.env.example](.env.example) file.

The only **required** environment variables are `DB_HOST` and `DAEMON_URL`.

> [!WARNING]
> In production, the Movim container should be served by a reverse proxy that handles TLS.

#### Container-Only Environment Variables

`TESTING_MODE` (not set by default)

If not empty, the Movim container is ran with a self-signed certificate for local testing and its web server will listen on port `8443` instead of `8080`. Also, the following environment variables are set with the given values, unless otherwise specified by the user already:
* `DAEMON_URL=https://127.0.0.1:8443`
* `DAEMON_DEBUG=true`
* `DAEMON_VERBOSE=true`

### Data Persistence

The following paths in the container should be mounted in a named volume or bind mounted on the host system:

| Path | Usage |
| --- | --- |
| `/var/www/movim/cache` | Internal cache (templates and other system files) |
| `/var/www/movim/log` | PHP logs |
| `/var/www/movim/public/cache` | Public caches (pictures, CSS, Javascript, etc.) |
| `/var/www/movim/public/images` | Profile pictures and banners |
| `/var/cache/picture_proxy` | [Picture proxy cache](https://github.com/movim/movim/blob/master/INSTALL.md#53-picture-proxy-cache) storage |

See the comments in the example [compose.yaml](compose.yaml) file for reference on how to do this in a compose file.
