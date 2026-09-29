/*
  This file is part of Edgehog.

  Copyright 2026 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import { describe, expect, it } from "vitest";
import {
  matrixToMode,
  modeToMatrix,
  modeToOctal,
  modeToSymbolic,
  octalToMode,
  octalDigitToTriad,
  triadToOctalDigit,
} from "./permissions";

describe("permissions utility", () => {
  describe("triadToOctalDigit and octalDigitToTriad", () => {
    it("converts 7 to full permissions", () => {
      const triad = octalDigitToTriad(7);
      expect(triad).toEqual({ read: true, write: true, execute: true });
      expect(triadToOctalDigit(triad)).toBe(7);
    });

    it("converts 5 to read and execute", () => {
      const triad = octalDigitToTriad(5);
      expect(triad).toEqual({ read: true, write: false, execute: true });
      expect(triadToOctalDigit(triad)).toBe(5);
    });

    it("converts 4 to read only", () => {
      const triad = octalDigitToTriad(4);
      expect(triad).toEqual({ read: true, write: false, execute: false });
      expect(triadToOctalDigit(triad)).toBe(4);
    });

    it("converts 0 to no permissions", () => {
      const triad = octalDigitToTriad(0);
      expect(triad).toEqual({ read: false, write: false, execute: false });
      expect(triadToOctalDigit(triad)).toBe(0);
    });
  });

  describe("modeToMatrix and matrixToMode", () => {
    it("handles 511 (0o777)", () => {
      const matrix = modeToMatrix(511);
      expect(matrix.user).toEqual({ read: true, write: true, execute: true });
      expect(matrix.group).toEqual({ read: true, write: true, execute: true });
      expect(matrix.others).toEqual({ read: true, write: true, execute: true });
      expect(matrixToMode(matrix)).toBe(511);
    });

    it("handles 493 (0o755)", () => {
      const matrix = modeToMatrix(493);
      expect(matrix.user).toEqual({ read: true, write: true, execute: true });
      expect(matrix.group).toEqual({ read: true, write: false, execute: true });
      expect(matrix.others).toEqual({
        read: true,
        write: false,
        execute: true,
      });
      expect(matrixToMode(matrix)).toBe(493);
    });

    it("handles 420 (0o644)", () => {
      const matrix = modeToMatrix(420);
      expect(matrix.user).toEqual({ read: true, write: true, execute: false });
      expect(matrix.group).toEqual({
        read: true,
        write: false,
        execute: false,
      });
      expect(matrix.others).toEqual({
        read: true,
        write: false,
        execute: false,
      });
      expect(matrixToMode(matrix)).toBe(420);
    });

    it("handles null / undefined / negative cleanly", () => {
      expect(matrixToMode(modeToMatrix(null))).toBe(0);
      expect(matrixToMode(modeToMatrix(undefined))).toBe(0);
      expect(matrixToMode(modeToMatrix(-1))).toBe(0);
    });
  });

  describe("modeToOctal and octalToMode", () => {
    it("converts mode to octal string", () => {
      expect(modeToOctal(511)).toBe("0777");
      expect(modeToOctal(511, false)).toBe("777");
      expect(modeToOctal(493)).toBe("0755");
      expect(modeToOctal(420)).toBe("0644");
      expect(modeToOctal(384)).toBe("0600");
      expect(modeToOctal(null)).toBe("");
      expect(modeToOctal(undefined)).toBe("");
    });

    it("parses octal strings with or without prefix", () => {
      expect(octalToMode("777")).toBe(511);
      expect(octalToMode("0777")).toBe(511);
      expect(octalToMode("0o777")).toBe(511);
      expect(octalToMode("755")).toBe(493);
      expect(octalToMode("0755")).toBe(493);
      expect(octalToMode("644")).toBe(420);
      expect(octalToMode("600")).toBe(384);
    });

    it("returns null for invalid octal strings", () => {
      expect(octalToMode("")).toBeNull();
      expect(octalToMode("abc")).toBeNull();
      expect(octalToMode("888")).toBeNull();
      expect(octalToMode("77777")).toBeNull();
    });
  });

  describe("modeToSymbolic", () => {
    it("formats symbolic unix permission string", () => {
      expect(modeToSymbolic(511)).toBe("rwxrwxrwx");
      expect(modeToSymbolic(493)).toBe("rwxr-xr-x");
      expect(modeToSymbolic(420)).toBe("rw-r--r--");
      expect(modeToSymbolic(384)).toBe("rw-------");
      expect(modeToSymbolic(null)).toBe("---------");
    });
  });
});
