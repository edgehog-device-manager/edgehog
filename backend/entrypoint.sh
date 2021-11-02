#!/bin/bash

./bin/edgehog eval "Elixir.Edgehog.Release.migrate" || exit 1

exec ./bin/edgehog $@
