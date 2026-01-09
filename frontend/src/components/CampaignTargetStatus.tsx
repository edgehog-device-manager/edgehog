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

import { defineMessages, FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  CampaignTargetStatus as CampaignTargetStatusType,
  CampaignTargetStatus_CampaignTargetStatusFragment$key,
} from "@/api/__generated__/CampaignTargetStatus_CampaignTargetStatusFragment.graphql";

import Icon from "@/components/Icon";
import "./CampaignTargetStatus.scss";

const CAMPAIGN_TARGET_STATUS_FRAGMENT = graphql`
  fragment CampaignTargetStatus_CampaignTargetStatusFragment on CampaignTarget {
    status
  }
`;

const messages = defineMessages<CampaignTargetStatusType>({
  IDLE: {
    id: "components.campaignTargetStatus.Idle",
    defaultMessage: "Idle",
  },
  IN_PROGRESS: {
    id: "components.campaignTargetStatus.InProgress",
    defaultMessage: "In progress",
  },
  SUCCESSFUL: {
    id: "components.campaignTargetStatus.Successful",
    defaultMessage: "Successful",
  },
  FAILED: {
    id: "components.campaignTargetStatus.Failed",
    defaultMessage: "Failed",
  },
});

const colors: Record<CampaignTargetStatusType, string> = {
  IDLE: "color-idle",
  IN_PROGRESS: "color-in-progress",
  SUCCESSFUL: "color-successful",
  FAILED: "color-failed",
};

type CampaignTargetStatusProps = {
  status: CampaignTargetStatusType;
};

const CampaignTargetStatus = ({ status }: CampaignTargetStatusProps) => (
  <span className={`campaign-target-status text-nowrap`}>
    <Icon icon="circle" className={`me-2 ${colors[status]}`} />
    <FormattedMessage id={messages[status].id} />
  </span>
);

type CampaignTargetStatusFragmentProps = {
  campaignTargetRef: CampaignTargetStatus_CampaignTargetStatusFragment$key;
};

const CampaignTargetStatusFragment = ({
  campaignTargetRef,
}: CampaignTargetStatusFragmentProps) => {
  const { status } = useFragment(
    CAMPAIGN_TARGET_STATUS_FRAGMENT,
    campaignTargetRef,
  );
  return <CampaignTargetStatus status={status} />;
};

type CampaignTargetStatusWrapperProps =
  | {
      status: CampaignTargetStatusType;
      campaignTargetRef?: never;
    }
  | {
      status?: never;
      campaignTargetRef: CampaignTargetStatus_CampaignTargetStatusFragment$key;
    };

const CampaignTargetStatusWrapper = (
  props: CampaignTargetStatusWrapperProps,
) =>
  props.campaignTargetRef ? (
    <CampaignTargetStatusFragment campaignTargetRef={props.campaignTargetRef} />
  ) : (
    <CampaignTargetStatus status={props.status} />
  );

export type { CampaignTargetStatusType };
export { messages as statusMessages };

export default CampaignTargetStatusWrapper;
