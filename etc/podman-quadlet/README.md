# Podman Quadlet Configuration

Copy these files to either `/etc/containers/systemd/` when running as root or `~/.config/containers/systemd` when running as a rootless user.

Be sure to read the [movim.container](movim.container) and [movim-db.container](movim-db.container) files for configuration notes and change as necessary.

# Running the Containers

> [!NOTE]
> When running as a rootless user, use `systemctl --user` instead of simply `systemctl` below.

Firstly, reload the Systemd daemon:
    systemctl daemon-reload

Now you can start the Movim container:
    systemctl start movim

To get the status of the Movim container:
    systemctl status movim

To stop Movim:
    systemctl stop movim

# Secrets

The `movim.container` and `movim-db.container` files mount a secret named `movim-db-password` as an environment variable for setting the Postgres database password. You can create it like so:

    printf "MY_PASSWORD" | podman secret create movim-db-password -

You may also reference the [Podman documentation](https://docs.podman.io/en/latest/markdown/podman-secret-create.1.html).
