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

import type { ZodError } from "zod";

import type { DeviceMappingData, LabelOption } from "./composeTypes";

export const clone = <T>(value: T): T =>
  typeof structuredClone === "function"
    ? structuredClone(value)
    : (JSON.parse(JSON.stringify(value)) as T);

export const asRecord = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};

export const asStringArray = (value: unknown): string[] => {
  if (typeof value === "string") return [value];
  if (!Array.isArray(value)) return [];

  return value.flatMap((item) => (typeof item === "string" ? [item] : []));
};

export const sameStrings = (a: string[], b: string[]) =>
  a.length === b.length && a.every((item, index) => item === b[index]);

export const parseMemory = (value: unknown): number | undefined => {
  if (typeof value === "number") return value;
  if (typeof value !== "string") return undefined;

  const match = value.trim().match(/^(\d+(?:\.\d+)?)\s*([bkmg]?)b?$/i);
  if (!match) return undefined;

  const amount = parseFloat(match[1]);
  const unit = match[2].toLowerCase();

  const multipliers: Record<string, number> = {
    "": 1,
    b: 1,
    k: 1024,
    m: 1024 ** 2,
    g: 1024 ** 3,
  };

  return Math.round(amount * multipliers[unit]);
};

export const parseIntValue = (value: unknown): number | undefined =>
  parseMemory(value);

export const restartPolicyToEdgehog = (
  value: unknown,
): { policy?: string; count?: number; warning?: string } => {
  if (typeof value !== "string") return { warning: `unsupported value` };

  const separator = value.indexOf(":");
  const rawPolicy = (separator === -1 ? value : value.slice(0, separator))
    .trim()
    .toLowerCase();
  const arg = separator === -1 ? undefined : value.slice(separator + 1).trim();

  const mapping: Record<string, string> = {
    no: "no",
    always: "always",
    "on-failure": "on_failure",
    unless_stopped: "unless_stopped",
    "unless-stopped": "unless_stopped",
  };

  const policy = mapping[rawPolicy];

  if (!policy)
    return { policy: undefined, warning: `unsupported value '${value}'` };
  if (arg !== undefined && arg !== "") {
    // only on-failure supports a retry count; anything else keeps the
    // previous warn-and-ignore behavior
    const count = Number(arg);

    if (policy !== "on_failure" || !Number.isInteger(count) || count < 0) {
      return {
        policy,
        warning: `restart argument '${arg}' is not supported and will be ignored`,
      };
    }

    return { policy, count };
  }

  return { policy };
};

export const restartPolicyToCompose = (
  policy?: string,
  count?: number,
): string | undefined => {
  if (!policy) return undefined;

  const mapping: Record<string, string> = {
    no: "no",
    always: "always",
    on_failure: "on-failure",
    unless_stopped: "unless-stopped",
  };

  const base = mapping[policy];

  if (!base) return undefined;
  if (base === "on-failure" && count != null) return `${base}:${count}`;

  return base;
};

export const envToKeyValuePairs = (
  value: unknown,
): { key: string; value: string }[] => {
  if (!value) return [];

  if (Array.isArray(value)) {
    return value.flatMap((entry) => {
      if (typeof entry !== "string") return [];

      const separator = entry.indexOf("=");

      if (separator === -1) {
        return [{ key: entry, value: "" }];
      }

      return [
        {
          key: entry.slice(0, separator),
          value: entry.slice(separator + 1),
        },
      ];
    });
  }

  if (typeof value === "object") {
    return Object.entries(asRecord(value)).map(([key, val]) => ({
      key,
      value: val == null ? "" : String(val),
    }));
  }

  return [];
};

export const splitVolumeShortSyntax = (
  entry: string,
): { source: string; target: string; mode?: string } | null => {
  const parts = entry.split(":").map((part) => part.trim());

  if (parts.length === 2 && parts.every((part) => part !== "")) {
    return { source: parts[0], target: parts[1] };
  }

  if (parts.length === 3 && parts.every((part) => part !== "")) {
    return { source: parts[0], target: parts[1], mode: parts[2] };
  }

  return null;
};

export const isBindSource = (source: string) =>
  source.startsWith("/") ||
  source.startsWith(".") ||
  source.startsWith("~") ||
  /^[A-Za-z]:[\\/]/.test(source);

export const deviceMappingFromEntry = (
  entry: string,
): DeviceMappingData | null => {
  const parts = entry.split(":").map((part) => part.trim());

  if (parts.length === 2 && parts.every((part) => part !== "")) {
    return {
      pathOnHost: parts[0],
      pathInContainer: parts[1],
      cgroupPermissions: "rwm",
    };
  }

  if (parts.length === 3 && parts.every((part) => part !== "")) {
    return {
      pathOnHost: parts[0],
      pathInContainer: parts[1],
      cgroupPermissions: parts[2],
    };
  }

  return null;
};

export const portBindingFromEntry = (
  entry: unknown,
  context: string,
  warnings: string[],
): string | null => {
  if (typeof entry === "string") {
    return entry === "" ? null : entry;
  }

  if (typeof entry === "number") {
    return String(entry);
  }

  const port = asRecord(entry);
  const target = port.target != null ? String(port.target) : "";
  const published = port.published != null ? String(port.published) : "";
  const protocol = typeof port.protocol === "string" ? port.protocol : "";

  if (target === "") {
    warnings.push(
      `${context}: port without a target is not supported and will be ignored`,
    );

    return null;
  }

  const unsupportedOptions = ["mode", "name", "app_protocol"].filter(
    (key) => port[key] != null,
  );

  if (unsupportedOptions.length > 0) {
    warnings.push(
      `${context}: port option(s) ${unsupportedOptions.join(", ")} are not supported and will be ignored`,
    );
  }

  const targetWithProtocol =
    protocol && protocol !== "tcp" ? `${target}/${protocol}` : target;

  if (port.host_ip != null && published !== "") {
    return `${String(port.host_ip)}:${published}:${targetWithProtocol}`;
  }

  if (published !== "") {
    return `${published}:${targetWithProtocol}`;
  }

  return targetWithProtocol;
};

export const extraHostsFromValue = (value: unknown): string[] => {
  if (Array.isArray(value)) {
    return value.flatMap((entry) => (typeof entry === "string" ? [entry] : []));
  }

  return Object.entries(asRecord(value)).flatMap(([host, address]) => {
    if (typeof address === "string") {
      return [`${host}:${address}`];
    }

    if (Array.isArray(address)) {
      return address.flatMap((ip) =>
        typeof ip === "string" ? [`${host}:${ip}`] : [],
      );
    }

    return [];
  });
};

export const labelToId = (
  options: LabelOption[] | undefined,
  label: string,
): string | null =>
  options?.find((option) => option.label === label)?.value ?? null;

export const idToLabel = (
  options: LabelOption[] | undefined,
  id: string,
): string | null =>
  options?.find((option) => option.value === id)?.label ?? null;

/**
 * Service keys that Edgehog can represent in its containers. Anything else is
 * kept in the compose file and reported as a warning.
 */
export const SUPPORTED_SERVICE_KEYS = new Set([
  "image",
  "environment",
  "ports",
  "networks",
  "network_mode",
  "extra_hosts",
  "hostname",
  "volumes",
  "tmpfs",
  "read_only",
  "storage_opt",
  "volume_driver",
  "restart",
  "privileged",
  "cap_add",
  "cap_drop",
  "mem_limit",
  "mem_reservation",
  "memswap_limit",
  "mem_swappiness",
  "cpu_period",
  "cpu_quota",
  "cpu_rt_period",
  "cpu_rt_runtime",
  "devices",
  "depends_on",
  "deploy",
  "user",
  "working_dir",
  "command",
  "entrypoint",
  "healthcheck",
  "labels",
  "sysctls",
  "ulimits",
  "logging",
  "blkio_config",
]);

export const formatSchemaIssues = (error: ZodError): string => {
  const parts = error.issues.slice(0, 5).map((issue) => {
    const location = issue.path.length > 0 ? issue.path.join(".") : "document";

    return `${location}: ${issue.message}`;
  });

  if (error.issues.length > 5) {
    parts.push(`…and ${error.issues.length - 5} more`);
  }

  return parts.join("; ");
};

/**
 * Compose accepts a plain string or a list of words for command/entrypoint.
 * The Edgehog form stores a single string, so lists are joined. This is
 * stable after the first pass: serializing always emits the string form.
 */
export const commandToString = (value: unknown): string | undefined => {
  if (typeof value === "string") return value === "" ? undefined : value;
  if (typeof value === "number") return String(value);
  if (!Array.isArray(value)) return undefined;

  const parts = value.flatMap((item) =>
    typeof item === "string" || typeof item === "number" ? [String(item)] : [],
  );

  return parts.length > 0 ? parts.join(" ") : undefined;
};

const durationMultipliers: Record<string, number> = {
  ns: 1,
  us: 1_000,
  ms: 1_000_000,
  s: 1_000_000_000,
  m: 60 * 1_000_000_000,
  h: 60 * 60 * 1_000_000_000,
};

/**
 * Parses compose duration strings ("30s", "1m30s", "500ms") into nanoseconds.
 * Plain numbers pass through as-is. Returns undefined when unparseable.
 */
export const parseDurationToNs = (value: unknown): number | undefined => {
  if (typeof value === "number")
    return Number.isInteger(value) && value >= 0 ? value : undefined;
  if (typeof value !== "string") return undefined;

  const text = value.trim().toLowerCase();

  if (text === "") return undefined;

  const matches = [...text.matchAll(/(\d+(?:\.\d+)?)\s*(ns|us|ms|s|m|h)/g)];

  if (matches.length === 0) return undefined;

  const consumed = matches.map((match) => match[0]).join("");

  if (consumed.replace(/\s+/g, "") !== text.replace(/\s+/g, ""))
    return undefined;

  return Math.round(
    matches.reduce(
      (total, match) =>
        total + parseFloat(match[1]) * durationMultipliers[match[2]],
      0,
    ),
  );
};

/**
 * Formats nanoseconds back to a compose duration, preferring the largest
 * unit that divides evenly so output stays readable ("30s", not "30000000000ns").
 */
export const formatNsToDuration = (ns: number): string => {
  const units: [string, number][] = [
    ["h", durationMultipliers.h],
    ["m", durationMultipliers.m],
    ["s", durationMultipliers.s],
    ["ms", durationMultipliers.ms],
    ["us", durationMultipliers.us],
    ["ns", 1],
  ];

  for (const [unit, size] of units) {
    if (ns >= size && ns % size === 0) return `${ns / size}${unit}`;
  }

  return `${ns}ns`;
};

/**
 * Normalizes a compose healthcheck test (NONE, CMD-SHELL, CMD arrays or a
 * plain string) to the single string the Edgehog form stores. CMD exec
 * arrays are joined; callers should warn that the shell form is emitted.
 */
export const healthcheckTestToString = (value: unknown): string | undefined => {
  if (typeof value === "string") return value === "" ? undefined : value;
  if (!Array.isArray(value) || value.length === 0) return undefined;

  const [first, ...rest] = value;

  if (first === "NONE") return "NONE";
  if (first === "CMD-SHELL" || first === "CMD" || first === "SHELL")
    return rest.map((item) => String(item)).join(" ");

  return value.map((item) => String(item)).join(" ");
};

/**
 * Emits the string form back as a CMD-SHELL test so re-imports are stable.
 */
export const healthcheckTestToCompose = (
  value: string | undefined,
): unknown => {
  if (!value) return undefined;
  if (value === "NONE") return ["NONE"];

  return ["CMD-SHELL", value];
};

/**
 * Coerces compose numbers-or-numeric-strings to integers.
 * Returns undefined when the value is not a valid integer.
 */
export const toInt = (value: unknown): number | undefined => {
  if (typeof value === "number")
    return Number.isInteger(value) ? value : undefined;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);

    return Number.isInteger(parsed) ? parsed : undefined;
  }

  return undefined;
};

/**
 * Converts a compose list-or-dict (labels, sysctls) to key/value pairs.
 * Map scalars are stringified; list entries split on the first "=".
 */
export const listOrDictToPairs = (
  value: unknown,
): { key: string; value: string }[] => envToKeyValuePairs(value);

export const pairsToMap = (
  pairs: { key: string; value: string }[] | undefined,
): Record<string, string> =>
  Object.fromEntries((pairs ?? []).map((p) => [p.key, p.value]));

/**
 * Parses a compose ulimits map ({name: int | {soft, hard}}) into the
 * [{name, soft, hard}] rows the form stores. A single value expands to
 * soft == hard so re-serialization stays stable.
 */
export const parseUlimits = (
  value: unknown,
  context: string,
  warnings: string[],
): { name: string; soft: number; hard: number }[] => {
  const record = asRecord(value);
  const result: { name: string; soft: number; hard: number }[] = [];

  for (const [name, raw] of Object.entries(record)) {
    if (typeof raw === "object" && raw !== null && !Array.isArray(raw)) {
      const limits = asRecord(raw);
      const soft = toInt(limits.soft);
      const hard = toInt(limits.hard);

      if (soft === undefined || hard === undefined) {
        warnings.push(
          `${context}: unsupported ulimit '${name}' is not supported and will be ignored`,
        );

        continue;
      }

      result.push({ name, soft, hard });

      continue;
    }

    const single = toInt(raw);

    if (single === undefined) {
      warnings.push(
        `${context}: unsupported ulimit '${name}' is not supported and will be ignored`,
      );

      continue;
    }

    result.push({ name, soft: single, hard: single });
  }

  return result;
};

/**
 * Parses blkio_config object lists ([{path, weight|rate}]) with
 * string-numeric coercion. Unparseable entries are warned and skipped.
 * Returns normalized {path, value} pairs; callers map value to weight/rate.
 */
export const parseBlkioEntries = (
  value: unknown,
  valueKey: string,
  context: string,
  warnings: string[],
): { path: string; value: number }[] => {
  if (!Array.isArray(value)) return [];

  const result: { path: string; value: number }[] = [];

  for (const entry of value) {
    const record = asRecord(entry);
    const path = typeof record.path === "string" ? record.path : "";
    const parsed = toInt(record[valueKey]);

    if (path === "" || parsed === undefined) {
      warnings.push(
        `${context}: unsupported blkio entry is not supported and will be ignored`,
      );

      continue;
    }

    result.push({ path, value: parsed });
  }

  return result;
};
