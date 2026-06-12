// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import compact from "lodash/compact";
import { useMemo, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  ContainersOverview_ContainerEdgeFragment$data,
  ContainersOverview_ContainerEdgeFragment$key,
} from "@/api/__generated__/ContainersOverview_ContainerEdgeFragment.graphql";

import Button from "@/components/Button";
import ContainerDetails from "@/components/ContainerDetails";
import "@/components/ContainersOverview.scss";
import { Card } from "react-bootstrap";

const CONTAINERS_TABLE_FRAGMENT = graphql`
  fragment ContainersOverview_ContainerEdgeFragment on ContainerConnection {
    edges {
      node {
        id
        name
        ...ContainerDetailsFragment
      }
    }
  }
`;

type ContainerRecord = NonNullable<
  ContainersOverview_ContainerEdgeFragment$data["edges"]
>[number]["node"];

type ContainersOverviewProps = {
  className?: string;
  containersRef: ContainersOverview_ContainerEdgeFragment$key;
};

const ContainersOverview = ({
  className,
  containersRef,
}: ContainersOverviewProps) => {
  const containersFragment = useFragment(
    CONTAINERS_TABLE_FRAGMENT,
    containersRef || null,
  );

  const containers = useMemo<ContainerRecord[]>(() => {
    return compact(containersFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [containersFragment]);

  const [selectedIndex, setSelectedIndex] = useState(0);

  const selectedContainer = containers?.[selectedIndex];

  if (containers.length === 0) {
    return (
      <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
        <p>
          <FormattedMessage
            id="components.ContainersOverview.noContainers"
            defaultMessage="No containers available."
          />
        </p>
      </Card>
    );
  }

  return (
    <div className={`containerLayout ${className ?? ""}`}>
      <div className="containerListCard">
        {containers.map((container: ContainerRecord, index: number) => (
          <Button
            variant="light"
            key={container.id}
            className={`containerListItem ${selectedIndex === index ? "active" : ""}`}
            onClick={() => setSelectedIndex(index)}
          >
            {container.name}
          </Button>
        ))}
      </div>

      {selectedContainer && <ContainerDetails container={selectedContainer} />}
    </div>
  );
};

export default ContainersOverview;
