/*
 * This file is part of Edgehog.
 *
 * Copyright 2023 - 2026 SECO Mind Srl
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

import type { ComponentProps } from "react";
import { graphql, useFragment } from "react-relay/hooks";
import { useIntl } from "react-intl";
import Chart from "react-apexcharts";

import type { CampaignStatsChart_CampaignStatsChartFragment$key } from "@/api/__generated__/CampaignStatsChart_CampaignStatsChartFragment.graphql";

import { statusMessages } from "@/components/CampaignTargetStatus";

const CAMPAIGN_PROGRESS_BAR_FRAGMENT = graphql`
  fragment CampaignStatsChart_CampaignStatsChartFragment on Campaign {
    idleTargetCount
    inProgressTargetCount
    failedTargetCount
    successfulTargetCount
  }
`;

type Props = {
  campaignRef: CampaignStatsChart_CampaignStatsChartFragment$key;
};

const CampaignStatsChart = ({ campaignRef }: Props) => {
  const {
    successfulTargetCount,
    failedTargetCount,
    inProgressTargetCount,
    idleTargetCount,
  } = useFragment(CAMPAIGN_PROGRESS_BAR_FRAGMENT, campaignRef);

  const intl = useIntl();
  const chartOptions: ComponentProps<typeof Chart>["options"] = {
    labels: [
      intl.formatMessage(statusMessages.SUCCESSFUL),
      intl.formatMessage(statusMessages.FAILED),
      intl.formatMessage(statusMessages.IN_PROGRESS),
      intl.formatMessage(statusMessages.IDLE),
    ],
    colors: [
      `var(--campaign-target-status_color_successful)`,
      `var(--campaign-target-status_color_failed)`,
      `var(--campaign-target-status_color_in-progress)`,
      `var(--campaign-target-status_color_idle)`,
    ],
    dataLabels: {
      enabled: true,
    },
    legend: {
      position: "right",
    },
    responsive: [
      {
        breakpoint: 1600,
        options: {
          legend: {
            position: "bottom",
          },
        },
      },
    ],
    plotOptions: {
      pie: {
        donut: {
          labels: {
            show: true,
            total: {
              show: true,
            },
          },
        },
      },
    },
  };

  return (
    <Chart
      options={chartOptions}
      type="donut"
      series={[
        successfulTargetCount,
        failedTargetCount,
        inProgressTargetCount,
        idleTargetCount,
      ]}
      height="250px"
    />
  );
};

export default CampaignStatsChart;
