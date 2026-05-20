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

import { graphql, useFragment } from "react-relay/hooks";

import type { hooks_ImageCredentialsOptionsFragment$key } from "@/api/__generated__/hooks_ImageCredentialsOptionsFragment.graphql";
import type { hooks_NetworksOptionsFragment$key } from "@/api/__generated__/hooks_NetworksOptionsFragment.graphql";
import type { hooks_VolumesOptionsFragment$key } from "@/api/__generated__/hooks_VolumesOptionsFragment.graphql";
import { hooks_ContainersOptionsFragment$key } from "@/api/__generated__/hooks_ContainersOptionsFragment.graphql";
import { hooks_SystemModelsOptionsFragment$key } from "@/api/__generated__/hooks_SystemModelsOptionsFragment.graphql";

type Option = {
  value: string;
  label: string;
};

export const IMAGE_CREDENTIALS_OPTIONS_FRAGMENT = graphql`
  fragment hooks_ImageCredentialsOptionsFragment on RootQueryType {
    listImageCredentials {
      edges {
        node {
          id
          label
          username
        }
      }
    }
  }
`;

export const NETWORKS_OPTIONS_FRAGMENT = graphql`
  fragment hooks_NetworksOptionsFragment on RootQueryType {
    networks {
      edges {
        node {
          id
          label
        }
      }
    }
  }
`;

export const VOLUMES_OPTIONS_FRAGMENT = graphql`
  fragment hooks_VolumesOptionsFragment on RootQueryType {
    volumes {
      edges {
        node {
          id
          label
        }
      }
    }
  }
`;

export const SYSTEM_MODELS_OPTIONS_FRAGMENT = graphql`
  fragment hooks_SystemModelsOptionsFragment on RootQueryType {
    systemModels {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

export const CONTAINERS_OPTIONS_FRAGMENT = graphql`
  fragment hooks_ContainersOptionsFragment on RootQueryType {
    containers {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

export const useImageCredentialOptions = (
  queryRef: hooks_ImageCredentialsOptionsFragment$key,
): Option[] => {
  const data = useFragment(IMAGE_CREDENTIALS_OPTIONS_FRAGMENT, queryRef);

  return (
    data.listImageCredentials?.edges?.flatMap((edge) => {
      if (!edge?.node) {
        return [];
      }

      return [
        {
          value: edge.node.id,
          label: `${edge.node.label} (${edge.node.username})`,
        },
      ];
    }) ?? []
  );
};

export const useNetworkOptions = (
  queryRef: hooks_NetworksOptionsFragment$key,
): Option[] => {
  const data = useFragment(NETWORKS_OPTIONS_FRAGMENT, queryRef);

  return (
    data.networks?.edges?.flatMap((edge) => {
      if (!edge?.node) {
        return [];
      }

      return [
        {
          value: edge.node.id,
          label: edge.node.label ?? "",
        },
      ];
    }) ?? []
  );
};

export const useVolumeOptions = (
  queryRef: hooks_VolumesOptionsFragment$key,
): Option[] => {
  const data = useFragment(VOLUMES_OPTIONS_FRAGMENT, queryRef);

  return (
    data.volumes?.edges?.flatMap((edge) => {
      if (!edge?.node) {
        return [];
      }

      return [
        {
          value: edge.node.id,
          label: edge.node.label ?? "",
        },
      ];
    }) ?? []
  );
};

export const useSystemModelOptions = (
  queryRef: hooks_SystemModelsOptionsFragment$key,
): Option[] => {
  const data = useFragment(SYSTEM_MODELS_OPTIONS_FRAGMENT, queryRef);

  return (
    data.systemModels?.edges?.flatMap((edge) => {
      if (!edge?.node) return [];

      return [
        {
          value: edge.node.id,
          label: edge.node.name,
        },
      ];
    }) ?? []
  );
};

export const useContainerOptions = (
  queryRef: hooks_ContainersOptionsFragment$key,
): Option[] => {
  const data = useFragment(CONTAINERS_OPTIONS_FRAGMENT, queryRef);

  return (
    data.containers?.edges?.flatMap((edge) => {
      if (!edge?.node) {
        return [];
      }

      return [
        {
          value: edge.node.id,
          label: edge.node.name,
        },
      ];
    }) ?? []
  );
};

export type { Option };
