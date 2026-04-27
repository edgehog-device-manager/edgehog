#!/usr/bin/env bash

# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Migration timestamps checker
# =============================================================================
# This script checks that new migrations and snapshots are generated after the
# ones already present in the repository.
#
# Usage:
#   ./check-migration-timestamps BASE HEAD      # check migrations timestamps
#                                               # of files changed between BASE
#                                               # and HEAD.
# =============================================================================

set -euo pipefail

BASE_SHA="$1"
HEAD_SHA="$2"

check_timestamp_ordering() {
    local label="$1"
    local dir="$2"
    local file_regex="$3"

    echo "Checking $label"

    mapfile -t added_files < <(git diff --name-only --diff-filter=A "$BASE_SHA" "$HEAD_SHA" -- "$dir")

    if [ "${#added_files[@]}" -eq 0 ]; then
        echo "No new $label added in this PR. Skipping check."
        echo "Done."
        return 0
    fi

    local filtered_files=()
    local file
    for file in "${added_files[@]}"; do
        if [[ "$file" =~ $file_regex ]]; then
            filtered_files+=("$file")
        fi
    done

    if [ "${#filtered_files[@]}" -eq 0 ]; then
        echo "No timestamped $label added in this PR. Skipping check."
        echo "Done."
        return 0
    fi

    local base_latest_ts_raw
    base_latest_ts_raw="$(
        git ls-tree -r --name-only "$BASE_SHA" -- "$dir" |
            sed -nE "s#${file_regex}#\\1#p" |
            sort |
            tail -n 1
    )"

    if [ -z "$base_latest_ts_raw" ]; then
        echo "No timestamped $label exists on base branch. Nothing to compare."
        echo "Done."
        return 0
    fi

    local base_latest_ts="$((10#$base_latest_ts_raw))"

    echo "Latest base timestamp: $base_latest_ts"
    echo "Files added by PR:"
    printf ' - %s\n' "${filtered_files[@]}"

    local invalid_count=0

    for file in "${filtered_files[@]}"; do
        if [[ "$file" =~ $file_regex ]]; then
            local file_ts_raw="${BASH_REMATCH[1]}"
            local file_ts="$((10#$file_ts_raw))"

            if [ "$file_ts" -le "$base_latest_ts" ]; then
                echo -ne "❌ Error: file=$file\nOutdated timestamp! '$file_ts_raw' is older than or equal to the base branch latest ('$base_latest_ts_raw'). Please rebase and generate a new timestamp."
                invalid_count=$((invalid_count + 1))
            fi
        fi
    done

    if [ "$invalid_count" -gt 0 ]; then
        echo "❌ Found $invalid_count out-of-order file(s) in $label."
        echo "Done."
        return 1
    fi

    echo "✅ $label ordering check passed."
    echo "Done."
}

check_timestamp_ordering \
    "migrations" \
    "backend/priv/repo/migrations" \
    '^backend/priv/repo/migrations/([0-9]{14})_.*\.exs$'

check_timestamp_ordering \
    "resource snapshots" \
    "backend/priv/resource_snapshots" \
    '^backend/priv/resource_snapshots/.*/([0-9]{14})\.json$'
