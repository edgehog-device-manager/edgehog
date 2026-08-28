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

import { useCallback, useMemo, useRef, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import Alert from "react-bootstrap/Alert";
import Button from "react-bootstrap/Button";
import Col from "react-bootstrap/Col";
import Form from "react-bootstrap/Form";
import Row from "react-bootstrap/Row";
import Stack from "react-bootstrap/Stack";

import type { ReleaseCreate_getOptions_Query$data } from "@/api/__generated__/ReleaseCreate_getOptions_Query.graphql";
import type { CreateReleaseInput } from "@/api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import {
  useNetworkOptions,
  useSystemModelOptions,
  useVolumeOptions,
} from "@/hooks/options";
import MonacoEditor from "@/components/ui/monaco-editor/MonacoEditor";
import MultiSelect from "@/components/ui/multi-select/MultiSelect";
import Icon from "@/components/ui/icon/Icon";
import { FormRow } from "@/components/ui/form-row/FormRow";
import FormFeedback from "@/forms/FormFeedback";
import { mapCreateContainerToInput } from "@/forms/CreateContainer";
import { containerSchema, type ContainerInputData } from "@/forms/validation";
import {
  composeToFormData,
  formDataToCompose,
  type ComposeServiceExtras,
  type MappingContext,
} from "./composeMapping";
import ServicePane from "./ServicePane";
import stableStringify from "./stableStringify";

type ServiceEntry = {
  key: string;
};

type ComposerState = {
  services: ServiceEntry[];
  serviceData: Record<string, ContainerInputData>;
  dependsOnByKey: Record<string, string[]>;
  extrasByKey: Record<string, ComposeServiceExtras>;
  topLevelExtras: Record<string, unknown>;
};

type ReleaseComposerProps = {
  queryRef: ReleaseCreate_getOptions_Query$data;
  onSubmit: (release: CreateReleaseInput) => void;
  isLoading: boolean;
};

const newKey = () =>
  typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : Math.random().toString(36).slice(2);

const emptyContainer = (): ContainerInputData => ({
  name: "",
  image: { reference: "" },
  portBindings: [],
  binds: [],
  volumes: [],
  extraHosts: [],
  tmpfs: [],
  capAdd: [],
  capDrop: [],
  storageOpt: [],
  env: [],
  networks: [],
  deviceMappings: [],
  deviceRequests: [],
});

const ReleaseComposer = ({
  queryRef,
  onSubmit,
  isLoading,
}: ReleaseComposerProps) => {
  const intl = useIntl();

  const networkOptions = useNetworkOptions(queryRef);
  const volumeOptions = useVolumeOptions(queryRef);
  const systemModelOptions = useSystemModelOptions(queryRef);

  const mappingContext = useMemo<MappingContext>(
    () => ({ networkOptions, volumeOptions }),
    [networkOptions, volumeOptions],
  );

  const [version, setVersion] = useState("");
  const [systemModels, setSystemModels] = useState<string[]>([]);
  const [state, setState] = useState<ComposerState>({
    services: [],
    serviceData: {},
    dependsOnByKey: {},
    extrasByKey: {},
    topLevelExtras: {},
  });
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
              deviceRequests: existing.deviceRequests ?? [],
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

  const allServicesValid =
    state.services.length > 0 &&
    state.services.every((entry) => validity[entry.key]);

  const canSubmit = version.trim() !== "" && allServicesValid && !isLoading;

  const handleSubmit = () => {
    if (!canSubmit) {
      return;
    }

    const currentState = stateRef.current;

    onSubmit({
      version: version.trim(),
      requiredSystemModels:
        systemModels.length > 0
          ? systemModels.map((id) => ({ id }))
          : undefined,
      containers: currentState.services.map((entry) => ({
        ...mapCreateContainerToInput(currentState.serviceData[entry.key]),
        dependsOn: currentState.dependsOnByKey[entry.key] ?? [],
      })),
    });
  };

  const serviceNames = useMemo(
    () =>
      Array.from(
        new Set(
          state.services
            .map((entry) => state.serviceData[entry.key]?.name ?? "")
            .filter(Boolean),
        ),
      ),
    [state],
  );

  return (
    <Stack gap={3}>
      <div className="bg-white border rounded-3 p-3">
        <Form onSubmit={(event) => event.preventDefault()}>
          <Stack direction="horizontal" gap={3} className="align-items-start">
            <FormRow
              id="release-composer-version"
              label={
                <FormattedMessage
                  id="components.apps.releases.release-composer.ReleaseComposer.versionLabel"
                  defaultMessage="Release Version"
                />
              }
              className="flex-grow-1"
            >
              <Form.Control
                value={version}
                onChange={(event) => setVersion(event.target.value)}
                isInvalid={version.trim() === ""}
              />
              <FormFeedback
                feedback={
                  version.trim() === ""
                    ? intl.formatMessage({
                        id: "components.apps.releases.release-composer.ReleaseComposer.versionRequired",
                        defaultMessage: "This field is required",
                      })
                    : undefined
                }
              />
            </FormRow>
          </Stack>
          <FormRow
            id="release-composer-system-models"
            className="mt-2"
            label={
              <FormattedMessage
                id="components.apps.releases.release-composer.ReleaseComposer.requiredSystemModelsLabel"
                defaultMessage="Required System Models"
              />
            }
          >
            <MultiSelect
              value={systemModels.map((id) => ({
                value: id,
                label:
                  systemModelOptions.find((option) => option.value === id)
                    ?.label ?? id,
              }))}
              options={systemModelOptions}
              onChange={(options) =>
                setSystemModels(options.map((option) => option.value))
              }
            />
          </FormRow>
          <Button
            variant="primary"
            className="mt-3"
            disabled={!canSubmit}
            onClick={handleSubmit}
          >
            <FormattedMessage
              id="components.apps.releases.release-composer.ReleaseComposer.createRelease"
              defaultMessage="Create Release"
            />
          </Button>
        </Form>
      </div>

      <Row className="g-3">
        <Col lg={5}>
          <div className="overflow-auto pe-1" style={{ maxHeight: "70vh" }}>
            {state.services.length === 0 && (
              <div className="border rounded-3 p-4 text-center text-muted bg-light mb-3">
                <FormattedMessage
                  id="components.apps.releases.release-composer.ReleaseComposer.noServicesHint"
                  defaultMessage="No containers yet. Add one or paste a docker-compose file on the right."
                />
              </div>
            )}
            {state.services.map((entry) => {
              const ownName = state.serviceData[entry.key]?.name ?? "";

              return (
                <ServicePane
                  key={entry.key}
                  queryRef={queryRef}
                  container={state.serviceData[entry.key] ?? emptyContainer()}
                  dependsOn={state.dependsOnByKey[entry.key] ?? []}
                  otherServiceNames={serviceNames.filter(
                    (name) => name !== ownName,
                  )}
                  syncVersion={syncVersion}
                  isValid={validity[entry.key] ?? false}
                  onContainerChange={(data, isValid) =>
                    handleContainerChange(entry.key, data, isValid)
                  }
                  onDependsOnChange={(values) =>
                    handleDependsOnChange(entry.key, values)
                  }
                  onRemove={() => handleRemoveService(entry.key)}
                />
              );
            })}
            <Button variant="secondary" onClick={handleAddService}>
              <Icon icon={"plus"} className="me-1" />
              <FormattedMessage
                id="components.apps.releases.release-composer.ReleaseComposer.addContainer"
                defaultMessage="Add Container"
              />
            </Button>
          </div>
        </Col>
        <Col lg={7}>
          <div style={{ position: "sticky", top: 0 }}>
            <div style={{ height: "70vh" }}>
              <MonacoEditor
                value={yamlText}
                language="yaml"
                autoFormat={false}
                fillHeight
                onChange={handleYamlChange}
              />
            </div>
            {parseError && (
              <Alert variant="danger" className="mt-2 mb-0">
                <Icon icon={"warning"} className="me-2" />
                <FormattedMessage
                  id="components.apps.releases.release-composer.ReleaseComposer.invalidYamlPrefix"
                  defaultMessage="Invalid docker-compose file:"
                />{" "}
                {parseError}
              </Alert>
            )}
            {warnings.length > 0 && (
              <Alert variant="warning" className="mt-2 mb-0">
                <strong>
                  <FormattedMessage
                    id="components.apps.releases.release-composer.ReleaseComposer.warningsTitle"
                    defaultMessage="Some settings could not be represented:"
                  />
                </strong>
                <ul className="mb-0 mt-1">
                  {Array.from(new Set(warnings)).map((warning) => (
                    <li key={warning}>{warning}</li>
                  ))}
                </ul>
              </Alert>
            )}
          </div>
        </Col>
      </Row>
    </Stack>
  );
};

export default ReleaseComposer;
