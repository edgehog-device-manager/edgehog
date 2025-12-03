/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2023, 2025 SECO Mind Srl
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

import type { ReactElement } from "react";
import { defineMessages, FormattedMessage, FormattedNumber } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  BatterySlotStatus,
  BatteryTable_batteryStatus$data,
  BatteryTable_batteryStatus$key,
} from "@/api/__generated__/BatteryTable_batteryStatus.graphql";

import Result from "@/components/Result";
import Table, { createColumnHelper } from "@/components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const BATTERY_TABLE_FRAGMENT = graphql`
  fragment BatteryTable_batteryStatus on Device {
    batteryStatus {
      slot
      status
      levelPercentage
      levelAbsoluteError
    }
  }
`;

const statusMessages = defineMessages<BatterySlotStatus>({
  CHARGING: {
    id: "components.BatteryTable.status.Charging",
    defaultMessage: "Charging",
  },
  DISCHARGING: {
    id: "components.BatteryTable.status.Discharging",
    defaultMessage: "Discharging",
  },
  EITHER_IDLE_OR_CHARGING: {
    id: "components.BatteryTable.status.Either_idle_or_charging",
    defaultMessage: "Idle/Charging",
  },
  FAILURE: {
    id: "components.BatteryTable.status.Failure",
    defaultMessage: "Failure",
  },
  IDLE: {
    id: "components.BatteryTable.status.Idle",
    defaultMessage: "Idle",
  },
  REMOVED: {
    id: "components.BatteryTable.status.Removed",
    defaultMessage: "Removed",
  },
  UNKNOWN: {
    id: "components.BatteryTable.status.Unknown",
    defaultMessage: "Unknown",
  },
});

type BatterySlot = NonNullable<
  BatteryTable_batteryStatus$data["batteryStatus"]
>[number];

const renderChargeLevel = (slot: BatterySlot): ReactElement | null => {
  switch (slot.status) {
    case "CHARGING":
    case "DISCHARGING":
    case "IDLE":
    case "EITHER_IDLE_OR_CHARGING":
      if (
        slot.levelPercentage === null ||
        Number(slot.levelAbsoluteError) >= 50
      ) {
        return null;
      }

      return (
        <FormattedNumber
          value={slot.levelPercentage / 100}
          maximumFractionDigits={2}
          style="percent"
        />
      );

    case null:
    case "FAILURE":
    case "REMOVED":
    case "UNKNOWN":
      return null;
  }
};

const columnHelper = createColumnHelper<BatterySlot>();
const columns = [
  columnHelper.accessor("slot", {
    header: () => (
      <FormattedMessage
        id="components.BatteryTable.slotTitle"
        defaultMessage="Slot"
      />
    ),
  }),
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.BatteryTable.statusTitle"
        defaultMessage="Status"
      />
    ),
    cell: ({ getValue }) => {
      const status = getValue();
      return status && <FormattedMessage id={statusMessages[status].id} />;
    },
  }),
  columnHelper.accessor("levelPercentage", {
    header: () => (
      <FormattedMessage
        id="components.BatteryTable.chargeLevelTitle"
        defaultMessage="Charge Level"
      />
    ),
    cell: ({ row }) => renderChargeLevel(row.original),
  }),
];

type Props = {
  className?: string;
  deviceRef: BatteryTable_batteryStatus$key;
};

const BatteryTable = ({ className, deviceRef }: Props) => {
  const { batteryStatus } = useFragment(BATTERY_TABLE_FRAGMENT, deviceRef);

  if (!batteryStatus || !batteryStatus.length) {
    return (
      <Result.EmptyList
        title={
          <FormattedMessage
            id="components.BatteryTable.noBattery.title"
            defaultMessage="No battery"
          />
        }
      >
        <FormattedMessage
          id="components.BatteryTable.noBattery.message"
          defaultMessage="The device has not detected any battery yet."
        />
      </Result.EmptyList>
    );
  }

  return (
    <Table
      className={className}
      columns={columns}
      data={batteryStatus}
      hideSearch
    />
  );
};

export default BatteryTable;
