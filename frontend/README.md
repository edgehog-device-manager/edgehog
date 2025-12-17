<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Edgehog frontend

Edgehog frontend is a standard web UI to interact with the Edgehog backend. It's built on top of other open source technologies, such as [`react`](https://react.dev/) and [`react-bootstrap`](https://react-bootstrap.netlify.app/). Like all React applications the first step to work/make it work is to install its dependencies.

```sh
npm install
```

## 🧑‍🔬 Testing the frontend

Launching unit tests for the frontend is done with the usual NPM command:

```sh
npm test
```

this runs the test suite and watches over file changes to re-run the tests for a test driven development approach.

## 🚀 Run the frontend

First, the frontend needs the backend to work. See backend [README](/backend/README.md#edgehog-backend) on how to run Edgehog backend.

You can then launch and interact with the frontend by running

```sh
npm run start
```
