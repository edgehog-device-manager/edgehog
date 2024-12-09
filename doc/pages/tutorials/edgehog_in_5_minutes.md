<!---
  Copyright 2023-2024 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Edgehog in 5 minutes

## Prerequisites

Edgehog interacts with devices through [Astarte](https://github.com/astarte-platform/astarte).
While it's possible to run an instance of Edgehog without the local instance of Astarte for development purposes,
it's recommended to setup Astarte locally for full functionality.

### Setup your local Astarte instance

The easiest way to setup local Astarte instance is to follow the [Astarte in 5 minutes](https://docs.astarte-platform.org/astarte/latest/010-astarte_in_5_minutes.html) guide, up until the creation of a `test` realm.

To make sure your astarte instance is working and up to date, try running this command:

```sh
$ curl api.astarte.localhost &> /dev/null && echo 'Connected!' || echo 'Astarte is unreachable'
```

If you get "Astarte is unreachable", make sure your running astarte version is >= v1.1.0

## Run a local Edgehog instance

To setup edgehog, you must first clone a copy of edgehog locally

```sh
$ git clone https://github.com/edgehog-device-manager/edgehog && cd edgehog
```

> If you just want to try out Edgehog without interacting with the device, run it without the Astarte instance:
>
> ```sh
> $ docker compose \
> $   -f docker-compose.yml \
> $   -f docker-compose.without-astarte.yml \
> $   up -d
> ```
>
> Then jump to the [populate the database section](#populate-the-database-and-log-in-to-edgehog).

Run Edgehog along with a local instance of Astarte with

```sh
$ docker compose up -d
```

Try navigating to `http://edgehog.localhost`: you should be presented with a login screen!

## Setup the environment

Open the `.env` file in your favorite text editor.
Here you can edit docker's variables to match your current environment.
Right now we're only interested in the `SEEDS_*` variables, which are used to populate the database.

| Variable                        | Description                                                                                           |
| ------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `SEEDS_REALM`                   | The name of your astarte realm. It should match what you've created in your astarte setup             |
| `SEEDS_REALM_PRIVATE_KEY_FILE`  | The location of the realm's private key file (`test_private.pem` from the Astarte in 5 minutes guide) |
| `SEEDS_TENANT_PRIVATE_KEY_FILE` | The location of the [tenant's private key file](#generate-a-key-pair-for-the-tenant)                  |
| `SEEDS_ASTARTE_BASE_API_URL`    | The endpoint for Astarte API.                                                                         |

If for whatever reason you don't want to edit the `.env` file, you can also export
environment variables of the same name.

`SEEDS_REALM` and `SEEDS_ASTARTE_BASE_API_URL` should already be set for you, so only edit those if
needed.

### Generate a key pair for the tenant

Although it is possible to use a default key, it is recommended to have your own key pair for the
tenant.

You should already have [`astartectl`](https://github.com/astarte-platform/astartectl#installation)
installed from the Astarte in 5 minutes guide.

```sh
$ astartectl utils gen-keypair acme
```

**Remember to update** the `.env` file with the `acme_private.pem` location!

## Populate the database and log in to Edgehog

Run this command to populate the database

```sh
$ docker compose exec edgehog-backend bin/edgehog eval Edgehog.Release.seed
```

This will create the tenant `acme-inc` and add a sample device to it.

> _"I had the wrong variables set, and now I can't run the seed again. What now?"_
> If this happens, the easiest solution is to just recreate the edgehog volumes:
>
> ```sh
> $ docker compose down -v && docker compose up -d
> ```

Nice! Now we have our tenant but we can't access to it yet, we need a token.
Luckily Edgehog includes a scripts to generate one!

First you'll need to make sure to have python version 3 installed.

```sh
$ python3 --version
Python 3.x.y
```

> While not mandatory, it is advised to use a python virtual environment to make sure your
> globally installed python packages don't mess with this script's dependencies and vice versa.
> Doing this is pretty straightforward, but you may need to install the `python3-venv` package if
> you are using a Debian/Ubuntu-based system.
>
> ```sh
> $ python3 -m venv pyenv
> $ source pyenv/bin/activate
> ```

Then, navigate to the `tools/` subdirectory and install the required dependencies

```sh
$ cd tools && pip install -r requirements.txt
```

Now you can generate the login token with

```sh
$ ./gen-edgehog-jwt -t tenant -k ../acme_private.pem
```

> If in the previous section you had decided not to use a custom key, use this command instead
>
> ```sh
> $ ./gen-edgehog-jwt -t tenant -k ../backend/priv/repo/seeds/keys/tenant_private.pem
> ```

You can finally navigate to `http://edgehog.localhost` in your browser and login to the
`acme-inc` tenant using your newly generated token.

## Test Astarte connection

Astarte connectivity may not work right away, as edgehog has not yet reconciled
its interfaces and triggers with astarte. Without waiting, we can force it to execute
the reconciler using:

```sh
$ docker compose exec edgehog-backend bin/edgehog rpc "Edgehog.Tenants.Tenant |> Ash.read!() |> Enum.each(&Edgehog.Tenants.reconcile_tenant/1)"
```

If you now connect a device to astarte and open or reload the edgehog web page,
you should see the new device in the appropriate section.

> You can use [stream-qt5-test](https://docs.astarte-platform.org/astarte/latest/010-astarte_in_5_minutes.html#stream-data).
> If you do so the device won't have any edgehog interface, but it will still show up as connected.

## Cleaning up

As with astarte, you can clean your environment by running

```sh
$ docker compose down
```

to stop all the running edgehog containers.
