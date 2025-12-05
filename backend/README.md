<!---
  Copyright 2021-2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Edgehog backend

Edgehog backend is the server with whom Edgehog frontend interacts. It's a [Phoenix](https://www.phoenixframework.org/) server that uses [Ash](https://www.ash-hq.org/) application framework.

## ⚙️ Setup your development environment

For building and running Edgehog backend locally, you'll need Elixir, Erlang and Postgres installed. To manage installed versions we recommend using a version manager such as [asdf](https://asdf-vm.com/). The versions we're using are specified in the `.tool-versions` file.

To install them, navigate to the root of the project and run:

```sh
asdf install
```

It may take some time until everything is finished.

## 🛠️ Build the backend

To build the Edgehog backend you first need to install dependencies by running:

```sh
mix deps.get
```

Then compile the source files with:

```sh
mix compile
```

## 🚀 Run the backend

Ideally the backend needs `astarte` to work. Check out [Astarte repository](https://github.com/astarte-platform/astarte) to learn how to run it on your environment, or follow the [Astarte in 5 minutes tutorial](https://docs.astarte-platform.org/astarte/latest/010-astarte_in_5_minutes.html) if you need all the functionality to be fully working. For most changes, it is usually sufficient to run the backend locally as described below.

First run a Postgres instance:

```sh
docker run --name edgehog-db -d -e "POSTGRES_HOST_AUTH_METHOD=trust" -p 5432:5432 --rm postgres
```

Then, the database must be created and setup. This is done by running migrations. Navigate to the backend folder (`./backend`) and run:

```sh
mix ecto.setup
```

The previous command creates the database with tables and populates it with seeds data. If you just want an empty database with no data, run `mix ecto.create`, then `mix ecto.migrate`.

Finally, run the Phoenix server:

```sh
mix phx.server
```

This starts a local backend instance on [`localhost:4000`](http://localhost:4000). Now you have Edgehog backend server up and running. Nice!

You can also start the server inside an interactive shell with

```sh
iex -S mix phx.server
```

> **Note:** To create, migrate and seed the database, and install dependencies, there's a convenient mix task: `mix setup`.

## 🧹 Code linting

Format code:

```sh
mix format
```

Check code formatting:

```sh
mix format --check-formatted
```

Run static code analysis with Credo to identify issues related to code consistency, readability, and potential refactoring opportunities:

```sh
mix credo
```

Run Dialyzer to analyze the code for potential issues such as type mismatches:

```sh
MIX_ENV=test mix dialyzer
```

## 🧑‍🔬 Testing the backend

Before running tests, you first need to start a Postgres instance. You can read how to run it in [Run the backend](#-run-the-backend) step.

Launch project tests:

```sh
mix test
```

This task starts the current application, loads up `test/test_helper.exs` and then, requires all files matching the `test/**/*_test.exs` pattern in parallel.

### 🌐 Testing in a production-like environment

You can also use the [`just`](https://just.systems) tasks defined in the top level of the repo if you need an `astarte` instance and a working device, but don't want to go through the setup described in the guide. See [Edgehog Just in Time](/doc/pages/tutorials/edgehog_just_in_time.md) for more information.
