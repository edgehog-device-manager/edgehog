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

export type PermissionTriad = {
  read: boolean;
  write: boolean;
  execute: boolean;
};

export type FilePermissionsMatrix = {
  user: PermissionTriad;
  group: PermissionTriad;
  others: PermissionTriad;
};

export type PermissionTarget = "user" | "group" | "others";
export type PermissionAction = "read" | "write" | "execute";

export const PERMISSION_PRESETS = [
  { label: "644 (Standard File)", mode: 0o644, octal: "0644" },
  { label: "755 (Executable)", mode: 0o755, octal: "0755" },
  { label: "600 (Private)", mode: 0o600, octal: "0600" },
  { label: "777 (Full Access)", mode: 0o777, octal: "0777" },
] as const;

export const triadToOctalDigit = (triad: PermissionTriad): number =>
  (triad.read ? 4 : 0) + (triad.write ? 2 : 0) + (triad.execute ? 1 : 0);

export const octalDigitToTriad = (digit: number): PermissionTriad => ({
  read: (digit & 4) === 4,
  write: (digit & 2) === 2,
  execute: (digit & 1) === 1,
});

export const matrixToMode = (matrix: FilePermissionsMatrix): number => {
  const u = triadToOctalDigit(matrix.user);
  const g = triadToOctalDigit(matrix.group);
  const o = triadToOctalDigit(matrix.others);
  return (u << 6) | (g << 3) | o;
};

export const modeToMatrix = (
  mode: number | null | undefined,
): FilePermissionsMatrix => {
  if (mode === undefined || mode === null || isNaN(mode) || mode < 0) {
    return {
      user: { read: false, write: false, execute: false },
      group: { read: false, write: false, execute: false },
      others: { read: false, write: false, execute: false },
    };
  }
  const sanitized = mode & 0o777;
  return {
    user: octalDigitToTriad((sanitized >> 6) & 7),
    group: octalDigitToTriad((sanitized >> 3) & 7),
    others: octalDigitToTriad(sanitized & 7),
  };
};

export const modeToOctal = (
  mode: number | null | undefined,
  includePrefix = true,
): string => {
  if (mode === undefined || mode === null || isNaN(mode) || mode < 0) {
    return "";
  }
  const octal = (mode & 0o777).toString(8).padStart(3, "0");
  return includePrefix ? `0${octal}` : octal;
};

export const octalToMode = (str: string): number | null => {
  const clean = str.trim().replace(/^0o?/i, "");
  if (!clean || !/^[0-7]{1,4}$/.test(clean)) return null;
  const parsed = parseInt(clean, 8);
  if (isNaN(parsed) || parsed < 0 || parsed > 0o777) return null;
  return parsed;
};

export const modeToSymbolic = (mode: number | null | undefined): string => {
  if (mode === undefined || mode === null || isNaN(mode) || mode < 0) {
    return "---------";
  }
  const m = modeToMatrix(mode);
  const triadToStr = (t: PermissionTriad) =>
    `${t.read ? "r" : "-"}${t.write ? "w" : "-"}${t.execute ? "x" : "-"}`;
  return `${triadToStr(m.user)}${triadToStr(m.group)}${triadToStr(m.others)}`;
};
