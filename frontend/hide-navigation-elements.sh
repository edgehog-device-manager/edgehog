#!/bin/sh
# SPDX-FileCopyrightText: 2026 SECO Mind Srl
# SPDX-License-Identifier: Apache-2.0

# This will replace the default value in index.html
# ${SECO_GARAGE_MODE:-false} uses the environment variable if set, otherwise defaults to false

sed -i "s/data-hide-navigation-elements=\"false\"/data-hide-navigation-elements=\"${HIDE_NAVIGATION_ELEMENTS:-false}\"/g" \
  /usr/share/nginx/html/index.html
