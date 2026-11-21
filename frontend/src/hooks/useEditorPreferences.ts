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

import { useCallback, useEffect, useState } from "react";

export type EditorPreferences = {
  vimEnabled: boolean;
  fontSize: number;
};

export const MIN_EDITOR_FONT_SIZE = 8;

export const MAX_EDITOR_FONT_SIZE = 40;

export const DEFAULT_EDITOR_FONT_SIZE = 14;

const STORAGE_KEY = "editor-preferences";

const PREFERENCES_EVENT = "edgehog:editor-preferences";

export const clampEditorFontSize = (fontSize: number) =>
  Math.min(
    MAX_EDITOR_FONT_SIZE,
    Math.max(MIN_EDITOR_FONT_SIZE, Math.round(fontSize)),
  );

const readStoredPreferences = (): EditorPreferences => {
  const defaults: EditorPreferences = {
    vimEnabled: false,
    fontSize: DEFAULT_EDITOR_FONT_SIZE,
  };

  try {
    const stored = localStorage.getItem(STORAGE_KEY);

    if (!stored) {
      return defaults;
    }

    const parsed = JSON.parse(stored) as Partial<EditorPreferences>;

    return {
      vimEnabled: parsed.vimEnabled === true,
      fontSize:
        typeof parsed.fontSize === "number"
          ? clampEditorFontSize(parsed.fontSize)
          : defaults.fontSize,
    };
  } catch {
    return defaults;
  }
};

export default function useEditorPreferences() {
  const [preferences, setPreferences] = useState<EditorPreferences>(
    readStoredPreferences,
  );

  const updatePreferences = useCallback(
    (updater: (previous: EditorPreferences) => EditorPreferences) => {
      setPreferences((previous) => {
        const updated = updater(previous);
        const next: EditorPreferences = {
          vimEnabled: updated.vimEnabled === true,
          fontSize: clampEditorFontSize(updated.fontSize),
        };

        if (
          next.vimEnabled === previous.vimEnabled &&
          next.fontSize === previous.fontSize
        ) {
          return previous;
        }

        try {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
        } catch {
          // storage unavailable, keep in-memory preference only
        }

        window.dispatchEvent(
          new CustomEvent(PREFERENCES_EVENT, { detail: next }),
        );

        return next;
      });
    },
    [],
  );

  useEffect(() => {
    const synchronize = () => setPreferences(readStoredPreferences());

    window.addEventListener(PREFERENCES_EVENT, synchronize);
    window.addEventListener("storage", synchronize);

    return () => {
      window.removeEventListener(PREFERENCES_EVENT, synchronize);
      window.removeEventListener("storage", synchronize);
    };
  }, []);

  return { preferences, updatePreferences };
}
