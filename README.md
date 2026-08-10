<div align="center">
    <h1>Movim Container</h1>
    <h4>An endorsed, community-maintained Movim image</h4>
    <img src="https://img.shields.io/github/v/release/delonium/movim-container?filter=!*-rev*&style=flat-square&label=Movim%20Release&color=%233D36C0">
    <a href="https://github.com/delonium/movim-container/actions/workflows/stable.yml">
        <img src="https://img.shields.io/github/actions/workflow/status/delonium/movim-container/stable.yml?style=flat-square&label=Latest">
    </a>
    <a href="https://github.com/delonium/movim-container/actions/workflows/master.yml">
        <img src="https://img.shields.io/github/actions/workflow/status/delonium/movim-container/master.yml?style=flat-square&label=Master">
    </a>
</div>

## About

> [!NOTE]
> This repository is currently a community-run placeholder, migration into the Movim organization is planned, provided all goes well.  

Movim is a distributed social network built on the XMPP protocol. This repository is a community effort to package Movim as an OCI container that can be deployed with Docker and Podman.

* **Movim Website**: [movim.eu](https://movim.eu)
* **Movim Repository**: [github.com/movim/movim](https://github.com/movim/movim)
* **Support Chatroom**: [movim@conference.movim.eu](xmpp:movim@conference.movim.eu)

## Architecture Overview

Movim requires a *webserver*, *PHP process manager (php-fpm)*, *database*, and *XMPP server*. This container image packages the webserver and php-fpm to host the Movim source. A [compose file](#compose-file) is provided to showcase a basic deployment **without an XMPP server**.

> [!NOTE]
> Movim does not include an XMPP server. If you wish to self-host Movim with an account under your own domain, consider hosting an XMPP server like [ejabberd](https://ejabberd.im/) (recommended) or [Prosody](https://prosody.im/).

If you are hosting an XMPP server, please check out the [Movim Wiki](https://github.com/movim/movim/wiki) for configuring your server to support all of Movim's features.

## Supported Platforms

* `amd64`
* `arm64`

## Compose File

See the [compose.yaml](compose.yaml) file for a commented compose example with a Postgres database.

## Podman Quadlets

See the [Podman Quadlets README](etc/podman-quadlet/README.md) for a collection of sample configuration files.

## Quickstart and Testing Mode

> [!WARNING]
> Movim requires a real domain name with TLS to function fully. Testing mode may have degraded behavior, but it will work enough to do most tasks and to get a feel of Movim.

Using the provided `compose.yaml` file without changes will launch Movim in testing mode, which allows trying Movim locally on your machine. You can launch the compose file with [Podman (main website)](https://podman.io/). Podman is a FOSS alternative to Docker that is available on all the main distributions.

Install `podman` and `podman-compose`, then run:

    podman compose up -d

After a few moments, you can access Movim in your browser at the following URL:

    https://127.0.0.1:8443

Note that testing mode uses a self-signed certificate, so you need to accept the security warning in your browser before opening the url.

### Running Daemon Commands

You can run Movim daemon commands by using `exec` on the running container. For example, here is how to set an admin when deploying Movim via the `compose.yaml` file:

    podman compose exec movim php daemon.php setAdmin <JID>

## Pinning

The `latest` tag references the latest stable Movim version. You can also pin your container to a specific version like so: 

    ghcr.io/delonium/movim-container:v0.34.1

See the [Tags and Versioning](#tags-and-versioning) section for a complete list of tags and the image retention policy.

> [!NOTE]
> Pinned `master` tag digests are subject to this repository's retention policy. See the [Master Pinning](#master-pinning) section for more information.

## Configuration

You can configure the container by setting the environment variables found in the [.env.example](https://github.com/movim/movim/blob/master/.env.example) file provided by the Movim repository.

The only **required** environment variables are:
* `DB_HOST`
* `DB_PASSWORD`
* `DAEMON_URL`

> [!TIP]
> See the comments in the example [compose.yaml](compose.yaml) file for reference on how to do this in a compose file.

> [!WARNING]
> In production, the Movim container should be served by a reverse proxy that handles TLS.

### Container-Only Environment Variables

#### General

`TESTING_MODE` **(not set by default)**

If not empty, the Movim container is ran with a self-signed certificate for local testing and its web server will listen on port `443` instead of `80`. Also, the following environment variables are set with the given values, unless otherwise specified by the user already:
* `DAEMON_URL=https://127.0.0.1:8443`
* `DAEMON_DEBUG=true`
* `DAEMON_VERBOSE=true`

`CHOWN_DATA` **(default: `1`)**

If set to `1`, the container will check the ownership of its data directories (see the [Data Persistence](#data-persistence) section) and chown them recursively as necessary. This is mainly useful for mounting data from an existing Movim installation.

#### Tweaks

You can adjust common PHP and NGINX configuration options.

<details>
<summary>Tweak Variables</summary>
    
| Variable | Default |
| --- | --- |
| PHP_MEMORY_LIMIT | 256M |
| PHP_UPLOAD_MAX_FILESIZE | 100M |
| PHP_POST_MAX_SIZE | 100M |
| PHP_OPCACHE_MEMORY | 256 |
| PHP_FPM_PM_MAX_CHILDREN | 20 |
| PHP_FPM_PM_START_SERVERS | 2 |
| PHP_FPM_PM_MIN_SPARE_SERVERS | 1 |
| PHP_FPM_PM_MAX_SPARE_SERVERS | 3 |
| PHP_FPM_PM_MAX_REQUESTS | 500 |
| NGINX_CLIENT_MAX_BODY_SIZE | 100M |

</details>

#### Convenience Tweaks

`MOVIM_UPLOAD_MAX_FILESIZE` **(not set by default)**

If not empty, configures both NGINX and PHP with a maximum uploaded file size. This is the same as setting the following tweaks to the same value: `PHP_UPLOAD_MAX_FILESIZE`, `PHP_POST_MAX_SIZE`, and `NGINX_CLIENT_MAX_BODY_SIZE`.

For example, if you wish to only allow file uploads under 80M, set this tweak to `80M`.

## Data Persistence

The following paths in the container should be mounted in a named volume or bind mounted on the host system:

| Path | Usage |
| --- | --- |
| `/var/www/movim/cache` | Internal cache (templates and other system files) |
| `/var/www/movim/log` | PHP logs |
| `/var/www/movim/public/cache` | Public caches (pictures, CSS, Javascript, etc.) |
| `/var/www/movim/public/images` | Profile pictures and banners |
| `/var/www/movim/public/emojis` | Custom emoji packs |
| `/var/cache/picture_proxy` | [Picture proxy cache](https://github.com/movim/movim/blob/master/INSTALL.md#53-picture-proxy-cache) storage |

> [!TIP]
> See the comments in the example [compose.yaml](compose.yaml) file for reference on how to do this in a compose file.

### Mounting Existing Data

If you wish to mount data from an existing Movim installation, the Movim root is under `/var/www/movim` in the container. Each of the data directories in your Movim installation root should be bind-mounted to the respective container data directories described in the table above. For example, if your Movim installation is installed under `/path-to/movim`, you should bind mount the `public/cache` directory with `/path-to/movim/public/cache:/var/www/movim/public/cache`, and so on.

Note that this container is based on Debian and runs Movim as the `www-data` user with uid/gid `33:33`. The container will automatically correct ownership as necessary upon startup (see the `CHOWN_DATA` variable in the [Configuration section](#container-only-environment-variables)).

You can disable `CHOWN_DATA` by setting it to `0` if you wish to correct the ownership of bind mounts manually.

## Tags and Versioning

This repository checks for Movim stable releases weekly and builds the Movim master branch daily. Release notes contain changes to the container image between Movim stable releases.

| Tag | Description |
| --- | --- |
| latest | The latest stable release |
| v0.34.1 | Pinned stable release |
| master | Development branch rebuilt daily |

### Dated Master Tags

There are also dated master tags that look like `master-YYYYMMDD`. These will only be published if the Movim repository has changed since the latest dated master tag.

### Revision Tags

This repository tags releases based on how and when the Movim repository tags releases. The only time release tags diverge is when a previously-built stable release is rebuilt with the latest changes from this repository. When this happens, a revision tag is published and the corresponding stable tag in the container registry is also updated.

Revision tags look like this: `v0.34.1-revN`, where `N` is the incremented revision number.

For the sake of pinning, the first build of a stable release has revision number `0`.

### Branch Tags

Tags prefixed with `br-` represent development container images built from a specific branch from *this* repository.

### Image Retention Policy

This repository always keeps stable version tags, revision tags, and the `master` tag.

The following other policies apply:
| Tag | Retention |
|---|---|
| Dated master tags | Only the 30 most recent ones are kept |
| Branch tags | Removed if older than 2 weeks |

#### Master Pinning

The `master` tag can be pinned by digest, but this digest will only persist as long as its corresponding dated tag does. As such, if you wish to update your instance only after reviewing changes on Movim's development branch, doing so with the dated master tags themselves, instead of using a `master` digest, may be preferable. The dated master tags allow easy reference to see if they exist in the container registry.

Here is the rule of thumb: if you pin your instance to the latest dated master tag at the moment, **update the pin within 30 days to avoid referencing a pruned container image**.
