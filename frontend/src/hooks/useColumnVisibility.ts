// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { useEffect, useState } from "react";

type ColumnVisibilityState = Record<string, boolean>;

const STORAGE_PREFIX = "table-column-visibility:";

export default function useColumnVisibility(
  storageKey: string | undefined,
  hiddenColumns: string[],
) {
  const key = storageKey ? `${STORAGE_PREFIX}${storageKey}` : undefined;

  const [columnVisibility, setColumnVisibility] =
    useState<ColumnVisibilityState>(() => {
      const defaultVisibility = hiddenColumns.reduce((acc, id) => {
        acc[id] = false;
        return acc;
      }, {} as ColumnVisibilityState);

      if (!key) {
        return defaultVisibility;
      }

      try {
        const stored = localStorage.getItem(key);

        if (!stored) {
          return defaultVisibility;
        }

        return {
          ...defaultVisibility,
          ...JSON.parse(stored),
        };
      } catch {
        return defaultVisibility;
      }
    });

  useEffect(() => {
    if (!key) {
      return;
    }
    localStorage.setItem(key, JSON.stringify(columnVisibility));
  }, [columnVisibility, key]);

  return {
    columnVisibility,
    setColumnVisibility,
  };
}
