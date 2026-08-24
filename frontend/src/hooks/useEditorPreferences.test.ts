/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { afterEach, describe, expect, it } from "vitest";
import { act, renderHook } from "@testing-library/react";

import useEditorPreferences, {
  DEFAULT_EDITOR_FONT_SIZE,
  MAX_EDITOR_FONT_SIZE,
  MIN_EDITOR_FONT_SIZE,
} from "./useEditorPreferences";

const STORAGE_KEY = "editor-preferences";

afterEach(() => {
  localStorage.removeItem(STORAGE_KEY);
});

describe("useEditorPreferences", () => {
  it("returns defaults when nothing is stored", () => {
    const { result } = renderHook(() => useEditorPreferences());

    expect(result.current.preferences).toEqual({
      vimEnabled: false,
      fontSize: DEFAULT_EDITOR_FONT_SIZE,
    });
  });

  it("persists changes to localStorage", () => {
    const { result } = renderHook(() => useEditorPreferences());

    act(() =>
      result.current.updatePreferences((previous) => ({
        ...previous,
        vimEnabled: true,
        fontSize: 20,
      })),
    );

    expect(JSON.parse(localStorage.getItem(STORAGE_KEY)!)).toEqual({
      vimEnabled: true,
      fontSize: 20,
    });
    expect(result.current.preferences.vimEnabled).toBe(true);
    expect(result.current.preferences.fontSize).toBe(20);
  });

  it("restores stored preferences and clamps invalid font sizes", () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ vimEnabled: true, fontSize: 9999 }),
    );

    const { result } = renderHook(() => useEditorPreferences());

    expect(result.current.preferences).toEqual({
      vimEnabled: true,
      fontSize: MAX_EDITOR_FONT_SIZE,
    });
  });

  it("falls back to defaults for corrupt stored values", () => {
    localStorage.setItem(STORAGE_KEY, "{not json");

    const { result } = renderHook(() => useEditorPreferences());

    expect(result.current.preferences).toEqual({
      vimEnabled: false,
      fontSize: DEFAULT_EDITOR_FONT_SIZE,
    });
  });

  it("synchronizes between hook instances and respects bounds", () => {
    const view = renderHook(() => useEditorPreferences());
    const utils = renderHook(() => useEditorPreferences());

    act(() =>
      view.result.current.updatePreferences((previous) => ({
        ...previous,
        fontSize: MIN_EDITOR_FONT_SIZE - 10,
      })),
    );

    expect(view.result.current.preferences.fontSize).toBe(MIN_EDITOR_FONT_SIZE);
    expect(utils.result.current.preferences.fontSize).toBe(
      MIN_EDITOR_FONT_SIZE,
    );
  });
});
