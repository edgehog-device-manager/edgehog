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
): { policy?: string; warning?: string } => {
  if (typeof value !== "string") return { warning: `unsupported value` };

  const [rawPolicy, arg] = value.split(":");

  const mapping: Record<string, string> = {
    no: "no",
    always: "always",
    "on-failure": "on_failure",
    unless_stopped: "unless_stopped",
    "unless-stopped": "unless_stopped",
  };

  const policy = mapping[rawPolicy.trim().toLowerCase()];

  if (!policy)
    return { policy: undefined, warning: `unsupported value '${value}'` };
  if (arg)
    return {
      policy,
      warning: `restart argument '${arg}' is not supported and will be ignored`,
    };

  return { policy };
};

export const restartPolicyToCompose = (policy?: string): string | undefined => {
  if (!policy) return undefined;

  const mapping: Record<string, string> = {
    no: "no",
    always: "always",
    on_failure: "on-failure",
    unless_stopped: "unless-stopped",
  };

  return mapping[policy];
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
