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

import { useState } from "react";
import { useIntl } from "react-intl";

import MonacoJsonEditor from "@/components/ui/monaco-json-editor/MonacoJsonEditor";

export type EnvVar = {
  key: string;
  value: string;
};

type Props = {
  value: EnvVar[];
  onChange: (vars: EnvVar[]) => void;
  error?: string | null;
};

const reduceEnv = (env: EnvVar[]): Record<string, string> =>
  env.reduce<Record<string, string>>((acc, cur) => {
    acc[cur.key] = cur.value;
    return acc;
  }, {});

const envToString = (env: EnvVar[]): string =>
  JSON.stringify(reduceEnv(env), null, 2);

const parseEnv = (text: string): EnvVar[] | null => {
  if (!text.trim()) return [];
  try {
    const parsed = JSON.parse(text);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      return Object.entries(parsed).map(([key, val]) => ({
        key,
        value: String(val ?? ""),
      }));
    }
    return null;
  } catch {
    return null;
  }
};

const EnvVarEditor = ({ value, onChange, error }: Props) => {
  const intl = useIntl();
  const [text, setText] = useState(() =>
    value.length ? envToString(value) : "{}",
  );
  const [localError, setLocalError] = useState<string | null>(null);

  const handleChange = (newText: string | undefined) => {
    const v = newText ?? "";
    setText(v);
    if (!v.trim()) {
      setLocalError(null);
      onChange([]);
      return;
    }
    const parsed = parseEnv(v);
    if (parsed === null) {
      try {
        JSON.parse(v);
        setLocalError(
          intl.formatMessage({
            id: "components.deploy.EnvVarEditor.expectedObject",
            defaultMessage: "Expected a JSON object",
          }),
        );
      } catch (e) {
        setLocalError(
          (e as Error).message ||
            intl.formatMessage({
              id: "components.deploy.EnvVarEditor.invalidJson",
              defaultMessage: "Invalid JSON",
            }),
        );
      }
      return;
    }
    setLocalError(null);
    onChange(parsed);
  };

  return (
    <MonacoJsonEditor
      value={text}
      defaultValue="{}"
      onChange={handleChange}
      error={error ?? localError ?? undefined}
    />
  );
};

export default EnvVarEditor;
