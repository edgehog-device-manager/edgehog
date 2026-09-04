/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
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

import { Tooltip } from "react-tooltip";
import { FormattedMessage } from "react-intl";

import { fieldExplanations } from "@/forms/index";
import Icon from "@/components/ui/icon/Icon";

type FieldKey =
  | "imageReference"
  | "imageCredentials"
  | "hostname"
  | "domainname"
  | "networkDisabled"
  | "networkMode"
  | "networks"
  | "dns"
  | "dnsOptions"
  | "dnsSearch"
  | "extraHosts"
  | "portBindings"
  | "exposedPorts"
  | "binds"
  | "volumes"
  | "volumeDriver"
  | "storageOpts"
  | "tmpfs"
  | "readOnlyRootfs"
  | "autoRemove"
  | "memory"
  | "memoryReservation"
  | "memorySwap"
  | "memorySwappiness"
  | "cpuShares"
  | "cpusetCpus"
  | "cpuPeriod"
  | "cpuQuota"
  | "cpuRealtimePeriod"
  | "cpuRealtimeRuntime"
  | "shmSize"
  | "oomScoreAdjustment"
  | "ulimits"
  | "privileged"
  | "capAdd"
  | "capDrop"
  | "cgroupsMode"
  | "ipcMode"
  | "usernsMode"
  | "pidMode"
  | "securityopt"
  | "maskedPaths"
  | "readonlyPaths"
  | "groupAdd"
  | "deviceCgroupRules"
  | "runtime"
  | "restartPolicy"
  | "restartPolicyMaximumRetryCount"
  | "stopSignal"
  | "stopTimeout"
  | "labels"
  | "sysctls"
  | "env"
  | "deviceMappings"
  | "driver"
  | "count"
  | "deviceIDs"
  | "capabilities"
  | "driverOptions"
  | "deviceRequests"
  | "user"
  | "workingDirectory"
  | "command"
  | "entrypoint"
  | "healthcheckTest"
  | "healthcheckInterval"
  | "healthcheckTimeout"
  | "healthcheckRetries"
  | "healthcheckStartPeriod"
  | "healthcheckStartInterval"
  | "blkioWeight"
  | "blkioWeightDevice"
  | "blkioDeviceReadBps"
  | "blkioDeviceWriteBps"
  | "blkioDeviceReadIops"
  | "blkioDeviceWriteIops"
  | "logType"
  | "logConfig";

function getFieldExplanation(field: FieldKey) {
  const titleKey = `${field}Title` as keyof typeof fieldExplanations;
  const descKey = `${field}Description` as keyof typeof fieldExplanations;
  const exampleKey = `${field}Example` as keyof typeof fieldExplanations;
  return {
    title:
      fieldExplanations[titleKey] ??
      ({
        id: `forms.fieldExplanation.${field}.title`,
        defaultMessage: field,
      } as unknown as (typeof fieldExplanations)[keyof typeof fieldExplanations]),
    description:
      fieldExplanations[descKey] ??
      ({
        id: `forms.fieldExplanation.${field}.description`,
        defaultMessage: "",
      } as unknown as (typeof fieldExplanations)[keyof typeof fieldExplanations]),
    example: fieldExplanations[exampleKey],
  };
}
interface FieldHelpProps {
  id: FieldKey;
  size?: number;
  children: React.ReactNode;
  itemsAlignment?: "baseline" | "center" | "start" | "end";
}

const FieldHelp = ({
  id,
  size = 17,
  children,
  itemsAlignment,
}: FieldHelpProps) => {
  const explanation = getFieldExplanation(id);

  const iconWrapperStyle = itemsAlignment
    ? { alignSelf: itemsAlignment }
    : { height: "38px" };

  return (
    <div className={`d-flex justify-content-center gap-2`}>
      <div className="flex-grow-1 w-100">{children}</div>

      <div
        data-tooltip-id={`tooltip-${id}`}
        className="d-flex align-items-center"
        style={iconWrapperStyle}
      >
        <Icon
          icon={"question"}
          style={{
            color: "gray",
            cursor: "pointer",
            fontSize: `${size}px`,
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.transform = "scale(1.2)";
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = "scale(1)";
          }}
        />
      </div>

      <Tooltip
        id={`tooltip-${id}`}
        place="top"
        className="max-w-md"
        style={{ zIndex: 9999, backgroundColor: "transparent" }}
      >
        <div
          className="bg-white border border shadow-sm p-1 "
          style={{ maxWidth: "260px" }}
        >
          <h6 className="fw-semibold mb-2 text-dark">
            <FormattedMessage {...explanation.title} />
          </h6>
          <hr className="text-dark mb-3 mt-0" />

          <p className="text-dark mb-2 small">
            <FormattedMessage {...explanation.description} />
          </p>

          {explanation.example && (
            <div
              className="p-2  bg-light border"
              style={{ backgroundColor: "whitesmoke" }}
            >
              <p className="m-0 text-secondary fw-semibold  small fst-italic">
                <span className="fw-bold me-1 text-dark">
                  <FormattedMessage
                    id="components.ui.field-help.FieldHelp.exampleTitle"
                    defaultMessage="Example:"
                  />
                </span>
                <FormattedMessage {...explanation.example} />
              </p>
            </div>
          )}
        </div>
      </Tooltip>
    </div>
  );
};

export default FieldHelp;
