#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 SECO Mind Srl
# SPDX-License-Identifier: Apache-2.0

# This script changes the forwarder version in `index.html`
# Uses the `FORWARDER_VERSION` variable.

sed -i 's|data-forwarder-version=\"[^\"]*\"|data-forwarder-version=\"'"$FORWARDER_VERSION"'\"|' /usr/share/nginx/html/index.html
