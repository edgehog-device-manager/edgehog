/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import { ReactNode, useCallback, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useMutation } from "react-relay/hooks";

import type { NetworkCreate_networkCreate_Mutation } from "@/api/__generated__/NetworkCreate_networkCreate_Mutation.graphql";

import Alert from "@/components/Alert";
import Page from "@/components/Page";
import { Route, useNavigate } from "@/Navigation";
import CreateNetworkForm, { NetworkData } from "@/forms/CreateNetwork";

const CREATE_NETWORK_MUTATION = graphql`
  mutation NetworkCreate_networkCreate_Mutation($input: CreateNetworkInput!) {
    createNetwork(input: $input) {
      result {
        id
      }
    }
  }
`;

const NetworkCreatePage = () => {
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);
  const navigate = useNavigate();

  const [createNetwork, isCreatingNetwork] =
    useMutation<NetworkCreate_networkCreate_Mutation>(CREATE_NETWORK_MUTATION);

  const handleCreateNetwork = useCallback(
    (network: NetworkData) => {
      const input: NetworkData = {
        label: network.label.trim(),
        internal: network.internal,
        enableIpv6: network.enableIpv6,
      };
      if (network.driver && network.driver.trim() !== "") {
        input.driver = network.driver.trim();
      }
      if (network.options && network.options.trim() !== "") {
        input.options = network.options.trim();
      }

      createNetwork({
        variables: { input },
        onCompleted(data, errors) {
          const networkId = data.createNetwork?.result?.id;
          if (networkId) {
            navigate({ route: Route.networks });
            return;
          }
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            setErrorFeedback(errorFeedback);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.NetworkCreate.creationErrorFeedback"
              defaultMessage="Could not create the Network, please try again."
            />,
          );
        },

        updater(store, data) {
          if (!data?.createNetwork?.result?.id) {
            return;
          }

          const network = store
            .getRootField("createNetwork")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const networks = root.getLinkedRecord("networks", {
            id: "root",
          });

          if (networks) {
            root.setLinkedRecords(
              networks
                ? [...(networks.getLinkedRecords("networks") || []), network]
                : [network],
              "networks",
            );
          }
        },
      });
    },
    [createNetwork, navigate],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.NetworkCreate.title"
            defaultMessage="Create Network"
          />
        }
      />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <CreateNetworkForm
          onSubmit={handleCreateNetwork}
          isLoading={isCreatingNetwork}
        />
      </Page.Main>
    </Page>
  );
};

export default NetworkCreatePage;
