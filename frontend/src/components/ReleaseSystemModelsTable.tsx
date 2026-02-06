// This file is part of Edgehog.
//
// Copyright 2025-2026 SECO Mind Srl
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

import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  ReleaseSystemModelsTable_SystemModelsFragment$data,
  ReleaseSystemModelsTable_SystemModelsFragment$key,
} from "@/api/__generated__/ReleaseSystemModelsTable_SystemModelsFragment.graphql";

import InfiniteTable from "@/components/InfiniteTable";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const RELEASE_SYSTEM_MODELS_TABLE_FRAGMENT = graphql`
  fragment ReleaseSystemModelsTable_SystemModelsFragment on Release {
    systemModels {
      id
      name
    }
  }
`;

type TableRecord = NonNullable<
  ReleaseSystemModelsTable_SystemModelsFragment$data["systemModels"]
>[number];

type ReleaseSystemModelsTableProps = {
  className?: string;
  systemModelsRef: ReleaseSystemModelsTable_SystemModelsFragment$key;
};

// TODO: decide if include more information about the system models other than name
const ReleaseSystemModelsTable = ({
  className,
  systemModelsRef,
}: ReleaseSystemModelsTableProps) => {
  const data = useFragment(
    RELEASE_SYSTEM_MODELS_TABLE_FRAGMENT,
    systemModelsRef,
  );

  const systemModels =
    data.systemModels?.filter(
      (sm): sm is NonNullable<typeof sm> => sm != null,
    ) ?? [];

  const columnHelper = createColumnHelper<TableRecord>();
  const columns = [
    columnHelper.accessor("name", {
      header: () => (
        <FormattedMessage
          id="components.ReleasesSystemModelsTable.nameTitle"
          defaultMessage="System Model Name"
        />
      ),
      cell: ({ row, getValue }) => (
        <Link
          route={Route.systemModelsEdit}
          params={{ systemModelId: row.original.id }}
        >
          {getValue()}
        </Link>
      ),
    }),
  ];

  return (
    <div>
      {systemModels.length ? (
        <InfiniteTable
          className={className}
          columns={columns}
          data={systemModels}
          hideSearch
        />
      ) : (
        <p>
          <FormattedMessage
            id="components.ReleaseSystemModelsTable.noSystemModels"
            defaultMessage="No supported system model specified. This release can be applied to any device."
          />
        </p>
      )}
    </div>
  );
};

export default ReleaseSystemModelsTable;
