<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Edgehog frontend

Edgehog frontend is a standard web UI to interact with the edgehog backend. It's built on top of other open source technologies, such as [`react`](https://react.dev/) and [`react-bootstrap`](https://react-bootstrap.netlify.app/). Like all react applications the first step to work/make it work is to install its dependecies.

```sh
npm install
```

# 🧑‍🔬 Testing the frontend

Testing the frontend is like testing each other react application

```sh
npm test
```

this runs the test suite and watches over file changes to re-run the tests for a test driven development approach.

# 🚀 Run the forntend (manual testing)

First, the frontend needs the backend to work (ideally the backend needs astarte to work. Check out [astarte repository](https://github.com/astarte-platform/astarte) to learn how to run it on your environment, or follow the[astarte in 5 minutes tutorial](https://docs.astarte-platform.org/astarte/latest/010-astarte_in_5_minutes.html)).

to run the backend, first run a postgres instance

```sh
docker run --name edgehog-db -d -e "POSTGRES_HOST_AUTH_METHOD=trust" -p 5432:5432 --rm postgres
```

then run the migrations. Go into the backend folder (`../backend`) and run

```sh
mix ecto.reset
```

finally, run an interactive shell on the backend

```sh
iex -S mix phx.server
```

this starts a local backend instance on `localhost:4000`.

You can then launch the frotend with

```sh
npm run start
```
