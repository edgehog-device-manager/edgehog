#!/bin/bash
# SPDX-FileCopyrightText: 2021-2022 SECO Mind Srl
# SPDX-License-Identifier: Apache-2.0

sed -i 's|data-backend-url=\"[^\"]*\"|data-backend-url=\"'"$BACKEND_URL"'\"|' /usr/share/nginx/html/index.html

