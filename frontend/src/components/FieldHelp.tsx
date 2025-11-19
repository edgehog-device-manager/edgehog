/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { Tooltip } from "react-tooltip";
import { FormattedMessage } from "react-intl";

import { fieldExplanations } from "forms/index";
import Icon from "components/Icon";

type FieldKey =
  | "imageReference"
  | "imageCredentials"
  | "hostname"
  | "restartPolicy"
  | "networkMode"
  | "networks"
  | "portBindings"
  | "binds"
  | "extraHosts"
  | "memory"
  | "memoryReservation"
  | "memorySwap"
  | "memorySwappiness"
  | "cpuPeriod"
  | "cpuQuota"
  | "cpuRealtimePeriod"
  | "cpuRealtimeRuntime"
  | "env"
  | "volumes"
  | "privileged"
  | "readOnlyRootfs"
  | "storageOpt"
  | "tmpfs"
  | "capAdd"
  | "capDrop"
  | "volumeDriver"
  | "deviceMappings";

function getFieldExplanation(field: FieldKey) {
  return {
    title: fieldExplanations[`${field}Title` as keyof typeof fieldExplanations],
    description:
      fieldExplanations[
        `${field}Description` as keyof typeof fieldExplanations
      ],
    example:
      fieldExplanations[`${field}Example` as keyof typeof fieldExplanations],
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
  size = 16,
  children,
  itemsAlignment = "baseline",
}: FieldHelpProps) => {
  const explanation = getFieldExplanation(id);

  return (
    <div
      className={`d-flex justify-content-center align-items-${itemsAlignment} gap-2`}
    >
      <div className="flex-grow-1 w-100">{children}</div>

      <div data-tooltip-id={`tooltip-${id}`}>
        <Icon
          icon={"faCircleQuestion"}
          style={{
            color: "white",
            backgroundColor: "lightgray",
            borderRadius: "50%",
            padding: "1.2px",
            cursor: "pointer",
            transition: "all 0.2s",
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
                    id="fieldExplanation.exampleTitle"
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
