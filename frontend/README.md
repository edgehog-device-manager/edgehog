<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Edgehog frontend

Edgehog frontend is a standard web UI to interact with the Edgehog backend. It's built on top of other open source technologies, such as [`react`](https://react.dev/) and [`react-bootstrap`](https://react-bootstrap.netlify.app/). Like all React applications the first step to work/make it work is to install its dependecies.

```sh
npm install
```

# 🧑‍🔬 Testing the frontend

Launching unit tests for the frontend is done with the usual NPM command:

```sh
npm test
```

this runs the test suite and watches over file changes to re-run the tests for a test driven development approach.

# 🚀 Run the forntend

First, the frontend needs the backend to work (ideally the backend needs Astarte to work). Check out [Astarte repository](https://github.com/astarte-platform/astarte) to learn how to run it on your environment, or follow the[Astarte in 5 minutes tutorial](https://docs.astarte-platform.org/astarte/latest/010-astarte_in_5_minutes.html)) if you need all the functionality to be fully working.
You can also use the [`just`](https://just.systems) tasks defined in the top level of the repo if you need an `astarte` instance and a working device, but don't want to go through the setup described in the guide.
For most changes, it is usually sufficient to run the backend locally as described below.
First run a Postgres instance

```sh
docker run --name edgehog-db -d -e "POSTGRES_HOST_AUTH_METHOD=trust" -p 5432:5432 --rm postgres
```

then the database must be created and setup by running migrations. Go into the backend folder (`../backend`) and run

```sh
mix ecto.reset
```

finally, run an interactive shell on the backend

```sh
iex -S mix phx.server
```

this starts a local backend instance on `localhost:4000`.

You can then launch and interact with the frontend by running

```sh
npm run start
```
