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

import React from "react";
import { Collapse, Button } from "react-bootstrap";
import { FormattedMessage } from "react-intl";

import Icon from "components/Icon";
import { fieldExplanations } from "../forms/index";

interface FieldExplanationSidebarProps {
  activeField: string | null;
  collapsed: boolean;
  setCollapsed: (collapsed: boolean) => void;
}
type FieldKey =
  | "imageReference"
  | "imageCredentials"
  | "hostname"
  | "restartPolicy"
  | "networkMode"
  | "networks"
  | "portBindings"
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

export const FieldExplanationSidebar: React.FC<
  FieldExplanationSidebarProps
> = ({ activeField, collapsed, setCollapsed }) => {
  const explanation = activeField
    ? getFieldExplanation(activeField as FieldKey)
    : null;

  return (
    <div
      className="bg-white border sticky-top ms-3 overflow-hidden"
      style={{
        width: collapsed ? "50px" : "300px",
        top: "20px",
        height: "fit-content",
        transition: "width 0.35s ease-in-out",
      }}
    >
      <div
        className={`d-flex align-items-center ${
          collapsed
            ? "justify-content-center py-2 px-2"
            : "justify-content-between border-bottom p-3"
        }`}
      >
        {!collapsed && (
          <h5 className="fw-semibold mb-0 text-dark">
            {explanation ? (
              <FormattedMessage {...explanation.title} />
            ) : (
              <FormattedMessage
                id="fieldExplanation.defaultTitle"
                defaultMessage="Field Explanation"
              />
            )}
          </h5>
        )}

        <Button
          variant="link"
          className={`p-0 ${collapsed ? "text-dark" : "text-secondary"}`}
          size="sm"
          onClick={() => setCollapsed(!collapsed)}
        >
          <Icon
            icon={collapsed ? "chevronRight" : "chevronLeft"}
            className="fs-5"
            style={{
              transform: collapsed ? "rotate(0deg)" : "rotate(180deg)",
              transition: "transform 0.3s ease",
            }}
          />
        </Button>
      </div>

      <Collapse in={!collapsed}>
        <div className="p-3 small text-secondary lh-lg">
          {explanation ? (
            <div className="gap-3">
              <FormattedMessage {...explanation.description} />
              {explanation.example && (
                <div className="p-2 rounded small bg-light border">
                  <p className="fst-italic text-muted mb-0">
                    <span className="fw-semibold me-1">
                      <FormattedMessage
                        id="fieldExplanation.exampleTitle"
                        defaultMessage="Example: "
                      />
                    </span>
                    <FormattedMessage {...explanation.example} />
                  </p>
                </div>
              )}
            </div>
          ) : (
            <div className="text-center py-2">
              <p className="text-muted mb-0">
                <FormattedMessage
                  id="fieldExplanation.focusMessage"
                  defaultMessage="Focus on a field to see its explanation."
                />
              </p>
            </div>
          )}
        </div>
      </Collapse>
    </div>
  );
};
