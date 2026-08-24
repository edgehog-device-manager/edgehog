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

import { useEffect } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import Button from "react-bootstrap/Button";
import Stack from "react-bootstrap/Stack";

import type { ReleaseCreate_getOptions_Query$data } from "@/api/__generated__/ReleaseCreate_getOptions_Query.graphql";

import Icon from "@/components/ui/icon/Icon";
import MultiSelect from "@/components/ui/multi-select/MultiSelect";
import {
  DeviceMappingsSection,
  DeviceRequestsSection,
  ImageSection,
  NameSection,
  NetworkSection,
  ResourceLimitsSection,
  RuntimeSection,
  SecuritySection,
  StorageSection,
} from "@/forms/CreateContainer";
import { containerSchema, type ContainerInputData } from "@/forms/validation";
import { FormRow } from "@/components/ui/form-row/FormRow";
import { useCollapsibleSections } from "@/components/ui/collapse-item/CollapseItem";
import "@/components/apps/containers/container-details/ContainerDetails.scss";

type ServicePaneProps = {
  queryRef: ReleaseCreate_getOptions_Query$data;
  container: ContainerInputData;
  dependsOn: string[];
  otherServiceNames: string[];
  syncVersion: number;
  onContainerChange: (data: ContainerInputData, isValid: boolean) => void;
  onDependsOnChange: (values: string[]) => void;
  onRemove: () => void;
};

const ServicePane = ({
  queryRef,
  container,
  dependsOn,
  otherServiceNames,
  syncVersion,
  onContainerChange,
  onDependsOnChange,
  onRemove,
}: ServicePaneProps) => {
  const intl = useIntl();
  const form = useForm<ContainerInputData>({
    resolver: zodResolver(containerSchema),
    defaultValues: container,
    mode: "onChange",
  });

  const { toggleSection, isSectionOpen } =
    useCollapsibleSections<string>(["image"]);

  const isValid = form.formState.isValid;

  useEffect(() => {
    const subscription = form.watch(() => {
      onContainerChange(form.getValues(), form.formState.isValid);
    });

    return () => subscription.unsubscribe();

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [form]);

  useEffect(() => {
    onContainerChange(form.getValues(), isValid);

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isValid]);

  useEffect(() => {
    if (syncVersion > 0) {
      form.reset(container);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [syncVersion]);

  const dependsOnOptions = otherServiceNames.map((name) => ({
    value: name,
    label: name,
  }));

  return (
    <div className="border rounded-3 p-2 mb-3 bg-light">
      <Stack gap={2}>
        <Stack direction="horizontal" gap={2} className="align-items-center">
          <span className="fw-bold flex-grow-1 text-truncate">
            {container.name || (
              <FormattedMessage
                id="components.ReleaseComposer.unnamedService"
                defaultMessage="Unnamed container"
              />
            )}
          </span>
          <Button
            variant="danger"
            size="sm"
            onClick={onRemove}
            title={intl.formatMessage({
              id: "components.ReleaseComposer.removeService",
              defaultMessage: "Remove",
            })}
          >
            <Icon className="text-white" icon={"delete"} />
          </Button>
        </Stack>

        <NameSection form={form} />

        <div className="bg-white border rounded-3 p-3">
          <FormRow
            id="release-composer-depends-on"
            label={
              <FormattedMessage
                id="components.ReleaseComposer.dependsOnLabel"
                defaultMessage="Depends on"
              />
            }
          >
            <MultiSelect
              value={dependsOn.map((name) => ({ value: name, label: name }))}
              options={dependsOnOptions}
              onChange={(options) =>
                onDependsOnChange(options.map((option) => option.value))
              }
            />
          </FormRow>
        </div>

        <ImageSection
          form={form}
          queryRef={queryRef}
          open={isSectionOpen("image")}
          onToggle={() => toggleSection("image")}
        />
        <NetworkSection
          form={form}
          queryRef={queryRef}
          open={isSectionOpen("network")}
          onToggle={() => toggleSection("network")}
        />
        <StorageSection
          form={form}
          queryRef={queryRef}
          open={isSectionOpen("storage")}
          onToggle={() => toggleSection("storage")}
        />
        <ResourceLimitsSection
          form={form}
          open={isSectionOpen("resourceLimits")}
          onToggle={() => toggleSection("resourceLimits")}
        />
        <SecuritySection
          form={form}
          open={isSectionOpen("securityCapabilities")}
          onToggle={() => toggleSection("securityCapabilities")}
        />
        <RuntimeSection
          form={form}
          open={isSectionOpen("runtimeEnvironment")}
          onToggle={() => toggleSection("runtimeEnvironment")}
        />
        <DeviceMappingsSection
          form={form}
          open={isSectionOpen("deviceMappings")}
          onToggle={() => toggleSection("deviceMappings")}
        />
        <DeviceRequestsSection
          form={form}
          open={isSectionOpen("deviceRequests")}
          onToggle={() => toggleSection("deviceRequests")}
        />
      </Stack>
    </div>
  );
};

export default ServicePane;
