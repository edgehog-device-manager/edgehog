#!/bin/bash
# SPDX-FileCopyrightText: 2021 SECO Mind Srl
# SPDX-License-Identifier: Apache-2.0

./bin/edgehog eval "Elixir.Edgehog.Release.migrate" || exit 1

exec ./bin/edgehog $@
