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

import { useCallback, useRef, useState } from "react";

import { containerSchema, type ContainerInputData } from "@/forms/validation";
import {
  composeToFormData,
  formDataToCompose,
  type ComposeServiceExtras,
  type MappingContext,
} from "./composeMapping";
import {
  emptyContainer,
  initialComposerState,
  newKey,
} from "./composerDefaults";
import type { ComposerState, ServiceEntry } from "./composerTypes";
import stableStringify from "./stableStringify";

type UseComposerStateArgs = {
  mappingContext: MappingContext;
};

export const useComposerState = ({ mappingContext }: UseComposerStateArgs) => {
  const [version, setVersion] = useState("");
  const [systemModels, setSystemModels] = useState<string[]>([]);
  const [state, setState] = useState<ComposerState>(initialComposerState);
  const [validity, setValidity] = useState<Record<string, boolean>>({});
  const [yamlText, setYamlText] = useState("services: {}\n");
  const [syncVersion, setSyncVersion] = useState(0);
  const [parseError, setParseError] = useState<string | null>(null);
  const [warnings, setWarnings] = useState<string[]>([]);

  const stateRef = useRef(state);

  const regenerateYaml = useCallback(
    (nextState: ComposerState) => {
      const { text, warnings: serializeWarnings } = formDataToCompose(
        {
          services: nextState.services.map((entry) => ({
            name: nextState.serviceData[entry.key]?.name ?? "",
            dependsOn: nextState.dependsOnByKey[entry.key] ?? [],
            container: nextState.serviceData[entry.key] ?? emptyContainer(),
            extras: nextState.extrasByKey[entry.key],
          })),
        },
        mappingContext,
        { topLevelExtras: nextState.topLevelExtras },
      );

      // skip identical output: avoids pointless buffer rewrites
      setYamlText((previous) => (previous === text ? previous : text));
      setParseError(null);
      setWarnings(serializeWarnings);
    },
    [mappingContext],
  );

  const updateState = useCallback(
    (updater: (prev: ComposerState) => ComposerState, source?: "form") => {
      const prev = stateRef.current;
      const next = updater(prev);

      if (next === prev) {
        return;
      }

      stateRef.current = next;
      setState(next);

      if (source === "form") {
        regenerateYaml(next);
      }
    },
    [regenerateYaml],
  );

  const handleContainerChange = useCallback(
    (key: string, data: ContainerInputData, isValid: boolean) => {
      const current = stateRef.current.serviceData[key];

      if (!current || stableStringify(current) !== stableStringify(data)) {
        updateState(
          (prev) => ({
            ...prev,
            // detach from the live react-hook-form values
            serviceData: { ...prev.serviceData, [key]: structuredClone(data) },
          }),
          "form",
        );
      }

      setValidity((prev) =>
        prev[key] === isValid ? prev : { ...prev, [key]: isValid },
      );
    },
    [updateState],
  );

  const commitParsedYaml = useCallback(
    (text: string) => {
      const result = composeToFormData(text, mappingContext);

      if (!result.ok) {
        setParseError(result.error);

        return;
      }

      setParseError(null);

      const prevState = stateRef.current;

      const keyByName = new Map<string, string>();

      prevState.services.forEach((entry) => {
        const name = prevState.serviceData[entry.key]?.name;

        if (name && !keyByName.has(name)) {
          keyByName.set(name, entry.key);
        }
      });

      const nextEntries: ServiceEntry[] = [];
      const nextData: Record<string, ContainerInputData> = {};
      const nextDeps: Record<string, string[]> = {};
      const nextValidity: Record<string, boolean> = {};
      const nextExtras: Record<string, ComposeServiceExtras> = {};

      result.data.services.forEach((service) => {
        const existingKey =
          service.name !== "" ? keyByName.get(service.name) : undefined;
        const key = existingKey ?? newKey();
        const existing = existingKey
          ? prevState.serviceData[existingKey]
          : undefined;

        const container: ContainerInputData = existing
          ? {
              ...service.container,
              image: {
                reference: service.container.image?.reference ?? "",
                imageCredentialsId: existing.image?.imageCredentialsId,
              },
              // form-only settings have no compose representation:
              // keep what the user configured in the panes
              deviceRequests: existing.deviceRequests ?? [],
              fileMounts: existing.fileMounts ?? [],
            }
          : service.container;

        nextEntries.push({ key });
        nextData[key] = container;
        nextDeps[key] = service.dependsOn;
        nextValidity[key] = containerSchema.safeParse(container).success;

        if (service.extras) {
          nextExtras[key] = service.extras;
        }
      });

      const nextState: ComposerState = {
        services: nextEntries,
        serviceData: nextData,
        dependsOnByKey: nextDeps,
        extrasByKey: nextExtras,
        topLevelExtras: result.topLevelExtras,
      };

      const changed =
        stableStringify(nextState.services.map((e) => e.key)) !==
          stableStringify(prevState.services.map((e) => e.key)) ||
        stableStringify(nextData) !== stableStringify(prevState.serviceData) ||
        stableStringify(nextDeps) !==
          stableStringify(prevState.dependsOnByKey) ||
        stableStringify(nextExtras) !==
          stableStringify(prevState.extrasByKey) ||
        stableStringify(result.topLevelExtras) !==
          stableStringify(prevState.topLevelExtras);

      setWarnings(result.warnings);
      setSyncVersion((prev) => (changed ? prev + 1 : prev));

      // mirror the parsed validity into state: without this, services coming
      // straight from the editor keep the orange badge because the form's
      // watch never fires
      setValidity((prev) => {
        const next = { ...prev };

        for (const key of Object.keys(prev)) {
          if (!nextData[key]) delete next[key];
        }

        for (const [key, value] of Object.entries(nextValidity)) {
          next[key] = value;
        }

        return next;
      });

      // commit without regenerating: the editor already holds this content
      updateState(() => nextState);
    },
    [mappingContext, updateState],
  );

  const handleYamlChange = useCallback(
    (text?: string) => {
      setYamlText(text ?? "");
      commitParsedYaml(text ?? "");
    },
    [commitParsedYaml],
  );

  const handleAddService = useCallback(() => {
    const key = newKey();

    updateState(
      (prev) => ({
        ...prev,
        services: [...prev.services, { key }],
        serviceData: { ...prev.serviceData, [key]: emptyContainer() },
        dependsOnByKey: { ...prev.dependsOnByKey, [key]: [] },
      }),
      "form",
    );

    setValidity((prev) => ({ ...prev, [key]: false }));
  }, [updateState]);

  const handleRemoveService = useCallback(
    (key: string) => {
      const removedName = stateRef.current.serviceData[key]?.name;

      updateState((prev) => {
        const restData = { ...prev.serviceData };
        const restDeps = { ...prev.dependsOnByKey };
        const restExtras = { ...prev.extrasByKey };

        delete restData[key];
        delete restDeps[key];
        delete restExtras[key];

        if (removedName) {
          for (const otherKey of Object.keys(restDeps)) {
            restDeps[otherKey] = restDeps[otherKey].filter(
              (name) => name !== removedName,
            );
          }
        }

        return {
          services: prev.services.filter((entry) => entry.key !== key),
          serviceData: restData,
          dependsOnByKey: restDeps,
          extrasByKey: restExtras,
          topLevelExtras: prev.topLevelExtras,
        };
      }, "form");

      setValidity((prev) => {
        const rest = { ...prev };

        delete rest[key];

        return rest;
      });
    },
    [updateState],
  );

  const handleDependsOnChange = useCallback(
    (key: string, values: string[]) => {
      updateState(
        (prev) => ({
          ...prev,
          dependsOnByKey: { ...prev.dependsOnByKey, [key]: values },
        }),
        "form",
      );
    },
    [updateState],
  );

  return {
    version,
    setVersion,
    systemModels,
    setSystemModels,
    state,
    stateRef,
    validity,
    yamlText,
    syncVersion,
    parseError,
    warnings,
    handleContainerChange,
    handleYamlChange,
    handleAddService,
    handleRemoveService,
    handleDependsOnChange,
  };
};
