<!---
  Copyright 2026 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Open FGA Edgehog models

Edgehog can be instructed to use OpenFGA as authz provider. This is a collection
of modules that represent the authorization model of edgehog.

## Prerequisites: Open FGA

This model needs openfga to run in order to verify and test it

```sh
docker run --rm -d \
    --name openfga \
    -p 8080:8080 \
    -p 8081:8081 \
    openfga/openfga run
```

## Test the model

In order to test the model it is possible to use the [openfga cli](https://github.com/openfga/cli) (<- instructions on how to set it up).

In order to test the models it's first necessary to compile them

```sh
# In the project root
fga model transform --file fga/openfga/model.mod --input-format=modular --output-format=json > fga/openfga/model.json
```

Then the tests can be run

```sh
# In the project's root
fga model test --tests fga/openfga/tests/*
```

A new task in the `just`file configuration has been added to automatize these steps

```sh
just test-openfga
```
