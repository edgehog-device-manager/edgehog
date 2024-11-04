/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

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

import React, { useCallback, useState } from "react";
import { Form, Button, Row, Col } from "react-bootstrap";
import { FormattedMessage } from "react-intl";
import { graphql, useLazyLoadQuery, useMutation } from "react-relay/hooks";

import type { AddAvailableApplications_GetApplicationsWithReleases_Query } from "api/__generated__/AddAvailableApplications_GetApplicationsWithReleases_Query.graphql";
import type { AddAvailableApplications_DeployRelease_Mutation } from "api/__generated__/AddAvailableApplications_DeployRelease_Mutation.graphql";

const GET_APPLICATIONS_WITH_RELEASES_QUERY = graphql`
  query AddAvailableApplications_GetApplicationsWithReleases_Query {
    applications(first: 10000) {
      results {
        id
        name
        releases(first: 10000) {
          edges {
            node {
              id
              version
            }
          }
        }
      }
    }
  }
`;

const DEPLOY_RELEASE_MUTATION = graphql`
  mutation AddAvailableApplications_DeployRelease_Mutation(
    $input: DeployReleaseInput!
  ) {
    deployRelease(input: $input) {
      result {
        id
        status
      }
      errors {
        message
      }
    }
  }
`;

type AddAvailableApplicationsProps = {
  deviceId: string;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
  onDeployComplete: () => void;
};

const AddAvailableApplications = ({
  deviceId,
  setErrorFeedback,
  onDeployComplete,
}: AddAvailableApplicationsProps) => {
  const [selectedApp, setSelectedApp] = useState<string | null>(null);
  const [selectedRelease, setSelectedRelease] = useState<string | null>(null);

  const data =
    useLazyLoadQuery<AddAvailableApplications_GetApplicationsWithReleases_Query>(
      GET_APPLICATIONS_WITH_RELEASES_QUERY,
      {},
      { fetchPolicy: "store-and-network" },
    );

  const [deployRelease, isDeploying] =
    useMutation<AddAvailableApplications_DeployRelease_Mutation>(
      DEPLOY_RELEASE_MUTATION,
    );

  const handleAppChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setSelectedApp(e.target.value);
    setSelectedRelease(null); // Reset release when app changes
  };

  const handleReleaseChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setSelectedRelease(e.target.value);
  };

  const handleDeploy = useCallback(() => {
    if (selectedRelease) {
      deployRelease({
        variables: {
          input: {
            deviceId: deviceId,
            releaseId: selectedRelease,
          },
        },
        onCompleted: (data, errors) => {
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          onDeployComplete(); // Trigger data refresh
          setSelectedApp(null); // Reset selected app
          setSelectedRelease(null); // Reset selected release
          setErrorFeedback(null);
        },
        onError: () => {
          setErrorFeedback(
            <FormattedMessage
              id="components.AddAvailableApplications.deployErrorFeedback"
              defaultMessage="Could not deploy the Application, please try again."
            />,
          );
        },
      });
    }
  }, [
    deviceId,
    selectedRelease,
    deployRelease,
    setErrorFeedback,
    onDeployComplete,
  ]);

  return (
    <Form.Group controlId="auto-deploy-group">
      <Form.Group as={Row} controlId="select-application" className="mt-3">
        <Form.Label column sm={2}>
          <FormattedMessage
            id="components.AddAvailableApplications.selectApplication"
            defaultMessage="Select Application"
          />
        </Form.Label>
        <Col sm={10}>
          <Form.Select value={selectedApp || ""} onChange={handleAppChange}>
            <option value="">
              <FormattedMessage
                id="components.AddAvailableApplications.selectAnApplication"
                defaultMessage="Select an application"
              />
            </option>
            {data.applications?.results?.map((app) => (
              <option key={app.id} value={app.id}>
                {app.name}
              </option>
            ))}
          </Form.Select>
        </Col>
      </Form.Group>

      <Form.Group as={Row} controlId="select-release" className="mt-3">
        <Form.Label column sm={2}>
          <FormattedMessage
            id="components.AddAvailableApplications.selectRelease"
            defaultMessage="Select Release"
          />
        </Form.Label>
        <Col sm={10}>
          <Form.Select
            value={selectedRelease || ""}
            onChange={handleReleaseChange}
            disabled={!selectedApp}
          >
            <option value="">
              <FormattedMessage
                id="components.AddAvailableApplications.selectARelease"
                defaultMessage="Select a release"
              />
            </option>
            {selectedApp &&
              data.applications?.results
                ?.find((app) => app.id === selectedApp)
                ?.releases.edges?.map(({ node }) => (
                  <option key={node.id} value={node.id}>
                    {node.version}
                  </option>
                ))}
          </Form.Select>
        </Col>
      </Form.Group>

      <Form.Group className="d-flex justify-content-end mt-2">
        <Button
          variant="primary"
          onClick={handleDeploy}
          disabled={!selectedRelease || isDeploying} // Disable until a release is selected or deploying
        >
          <FormattedMessage
            id="components.AddAvailableApplications.deployButton"
            defaultMessage="Deploy"
          />
        </Button>
      </Form.Group>
    </Form.Group>
  );
};

export default AddAvailableApplications;
