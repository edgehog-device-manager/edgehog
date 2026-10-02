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

import { useMemo } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import Alert from "@/components/ui/alert/Alert";
import Button from "@/components/ui/button/Button";
import Col from "@/components/ui/col/Col";
import Form from "@/components/ui/form/Form";
import Row from "@/components/ui/row/Row";
import Stack from "@/components/ui/stack/Stack";

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
import type { MappingContext } from "./composeMapping";
import { emptyContainer } from "./composerDefaults";
import { useComposerState } from "./useComposerState";
import ServicePane from "./ServicePane";

type ReleaseComposerProps = {
  queryRef: ReleaseCreate_getOptions_Query$data;
  onSubmit: (release: CreateReleaseInput) => void;
  isLoading: boolean;
};

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

  const {
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
  } = useComposerState({ mappingContext });

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
