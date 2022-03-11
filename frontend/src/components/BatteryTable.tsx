/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

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

import { FormattedMessage, FormattedNumber } from "react-intl";

import Table from "components/Table";
import type { Column } from "components/Table";
import type { BatteryStatus } from "api/__generated__/Device_batteryStatus.graphql";

type BatterySlotProps = {
  slot: string;
  levelPercentage: number | null;
  levelAbsoluteError: number | null;
  status: BatteryStatus | null;
};

const renderBatteryStatus = (status: BatterySlotProps["status"]) => {
  switch (status) {
    case "CHARGING":
      return (
        <FormattedMessage
          id="components.BatteryTable.status.Charging"
          defaultMessage="Charging"
        />
      );
    case "DISCHARGING":
      return (
        <FormattedMessage
          id="components.BatteryTable.status.Discharging"
          defaultMessage="Discharging"
        />
      );
    case "IDLE":
      return (
        <FormattedMessage
          id="components.BatteryTable.status.Idle"
          defaultMessage="Idle"
        />
      );
    case "EITHER_IDLE_OR_CHARGING":
      return (
        <FormattedMessage
          id="components.BatteryTable.status.Either_idle_or_charging"
          defaultMessage="Idle/Charging"
        />
      );
    case "REMOVED":
      return (
        <FormattedMessage
          id="components.BatteryTable.status.Removed"
          defaultMessage="Removed"
        />
      );
    case "FAILURE":
      return (
        <FormattedMessage
          id="components.BatteryTable.status.Failure"
          defaultMessage="Failure"
        />
      );
    case "UNKNOWN":
      return (
        <FormattedMessage
          id="components.BatteryTable.status.Unknown"
          defaultMessage="Unknown"
        />
      );

    case null:
      return null;

    default:
      return null;
  }
};

const renderChargeLevel = (slot: BatterySlotProps) => {
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
          // FormattedNumber has custom style property
          // eslint-disable-next-line react/style-prop-object
          style="percent"
        />
      );

    default:
      return null;
  }
};

const columns: Column<BatterySlotProps>[] = [
  {
    accessor: "slot",
    Header: (
      <FormattedMessage
        id="components.BatteryTable.slotTitle"
        defaultMessage="Slot"
      />
    ),
  },
  {
    accessor: "status",
    Header: (
      <FormattedMessage
        id="components.BatteryTable.statusTitle"
        defaultMessage="Status"
      />
    ),
    Cell: ({ value }) => renderBatteryStatus(value),
  },
  {
    accessor: "levelPercentage",
    Header: (
      <FormattedMessage
        id="components.BatteryTable.chargeLevelTitle"
        defaultMessage="Charge Level"
      />
    ),
    Cell: ({ row }) => renderChargeLevel(row.original),
  },
];

interface Props {
  className?: string;
  data: BatterySlotProps[];
}

const BatteryTable = ({ className, data }: Props) => {
  return (
    <Table className={className} columns={columns} data={data} hideSearch />
  );
};

export type { BatterySlotProps };

export default BatteryTable;
