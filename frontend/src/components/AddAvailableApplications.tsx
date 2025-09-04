/*
  This file is part of Edgehog.

  Copyright 2024 - 2025 SECO Mind Srl

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

import React, { useCallback, useState, useMemo } from "react";
import { Form, Button, Row, Col } from "react-bootstrap";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useLazyLoadQuery, useMutation } from "react-relay/hooks";
import Select, { SingleValue } from "react-select";

import type { AddAvailableApplications_GetApplicationsWithReleases_Query } from "api/__generated__/AddAvailableApplications_GetApplicationsWithReleases_Query.graphql";
import type { AddAvailableApplications_DeployRelease_Mutation } from "api/__generated__/AddAvailableApplications_DeployRelease_Mutation.graphql";

const GET_APPLICATIONS_WITH_RELEASES_QUERY = graphql`
  query AddAvailableApplications_GetApplicationsWithReleases_Query(
    $filter: ApplicationFilterInput
  ) {
    applications(first: 10000, filter: $filter) {
      edges {
        node {
          id
          name
          releases(first: 10000) {
            edges {
              node {
                id
                version
                systemModels {
                  name
                }
              }
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
        state
      }
      errors {
        message
      }
    }
  }
`;

type AddAvailableApplicationsProps = {
  deviceId: string;
  systemModelName: string | undefined;
  isOnline: boolean;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
  onDeployComplete: () => void;
};

type SelectOption = {
  value: string;
  label: string;
  disabled: boolean;
};

const AddAvailableApplications = ({
  deviceId,
  systemModelName,
  isOnline,
  setErrorFeedback,
  onDeployComplete,
}: AddAvailableApplicationsProps) => {
  const intl = useIntl();

  const [selectedApp, setSelectedApp] = useState<string | null>(null);
  const [selectedRelease, setSelectedRelease] = useState<string | null>(null);

  const data =
    useLazyLoadQuery<AddAvailableApplications_GetApplicationsWithReleases_Query>(
      GET_APPLICATIONS_WITH_RELEASES_QUERY,
      {
        filter: {
          releases: {
            or: [
              {
                systemModels: {
                  name: { eq: systemModelName },
                },
              },
              {
                systemModels: {
                  name: { isNil: true },
                },
              },
            ],
          },
        },
      },
      { fetchPolicy: "store-and-network" },
    );

  const applicationOptions: SelectOption[] = useMemo(() => {
    if (!data.applications?.edges) return [];

    return data.applications.edges.map((app) => ({
      value: app.node.id,
      label: app.node.name,
      disabled: false,
    }));
  }, [data.applications?.edges]);

  const selectedApplicationOption = useMemo(() => {
    return (
      applicationOptions.find((option) => option.value === selectedApp) || null
    );
  }, [applicationOptions, selectedApp]);

  const releaseOptions: SelectOption[] = useMemo(() => {
    if (!selectedApp || !data.applications?.edges) return [];

    const selectedApplication = data.applications.edges.find(
      (app) => app.node.id === selectedApp,
    );

    if (!selectedApplication?.node.releases.edges) return [];

    return selectedApplication.node.releases.edges.map(({ node: release }) => {
      const systemModelNames = release.systemModels?.map((sm) => sm.name) ?? [];

      const hasSystemModel = !!systemModelName;
      const matchesSystemModel =
        hasSystemModel && systemModelNames.includes(systemModelName);
      const appliesToAll = systemModelNames.length === 0;

      const enabled = matchesSystemModel || appliesToAll;

      return {
        value: release.id,
        label: release.version,
        disabled: !enabled,
      };
    });
  }, [selectedApp, data.applications?.edges, systemModelName]);

  const selectedReleaseOption = useMemo(() => {
    return (
      releaseOptions.find((option) => option.value === selectedRelease) || null
    );
  }, [releaseOptions, selectedRelease]);

  const [deployRelease, isDeploying] =
    useMutation<AddAvailableApplications_DeployRelease_Mutation>(
      DEPLOY_RELEASE_MUTATION,
    );

  const handleAppChange = (option: SingleValue<SelectOption>) => {
    if (!isOnline) {
      setErrorFeedback(
        <FormattedMessage
          id="components.AddAvailableApplications.deviceOfflineError"
          defaultMessage="The device is disconnected. You cannot deploy an application while it is offline."
        />,
      );
      return;
    }

    setSelectedApp(option?.value || null);
    setSelectedRelease(null); // Reset release when app changes
  };

  const handleReleaseChange = (option: SingleValue<SelectOption>) => {
    setSelectedRelease(option?.value || null);
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
        onCompleted: (_data, errors) => {
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
          <Select
            value={selectedApplicationOption}
            onChange={handleAppChange}
            options={applicationOptions}
            isClearable
            placeholder={intl.formatMessage({
              id: "components.AddAvailableApplications.searchPlaceholder",
              defaultMessage: "Search or select an application...",
            })}
            noOptionsMessage={({ inputValue }) =>
              inputValue
                ? intl.formatMessage(
                    {
                      id: "components.AddAvailableApplications.noApplicationsFoundMatching",
                      defaultMessage:
                        'No applications found matching "{inputValue}"',
                    },
                    { inputValue },
                  )
                : intl.formatMessage({
                    id: "components.AddAvailableApplications.noApplicationsAvailable",
                    defaultMessage: "No applications available",
                  })
            }
            filterOption={(option, inputValue) => {
              // Only search by application name (label), not by ID (value)
              return option.label
                .toLowerCase()
                .includes(inputValue.toLowerCase());
            }}
          />
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
          <Select
            value={selectedReleaseOption}
            onChange={handleReleaseChange}
            options={releaseOptions}
            isClearable
            placeholder={intl.formatMessage({
              id: "components.AddAvailableApplications.selectARelease",
              defaultMessage: "Select a release",
            })}
            noOptionsMessage={({ inputValue }) =>
              inputValue
                ? intl.formatMessage(
                    {
                      id: "components.AddAvailableApplications.noReleasesFoundMatching",
                      defaultMessage:
                        'No releases found matching "{inputValue}"',
                    },
                    { inputValue },
                  )
                : selectedApp
                  ? intl.formatMessage({
                      id: "components.AddAvailableApplications.noReleasesAvailable",
                      defaultMessage:
                        "No releases available for this application",
                    })
                  : intl.formatMessage({
                      id: "components.AddAvailableApplications.selectApplicationFirst",
                      defaultMessage: "Please select an application first",
                    })
            }
            filterOption={(option, inputValue) => {
              // Only search by release version (label), not by ID (value)
              return option.label
                .toLowerCase()
                .includes(inputValue.toLowerCase());
            }}
            isDisabled={!selectedApp}
            isOptionDisabled={(option) => option.disabled}
          />
        </Col>
      </Form.Group>

      <Form.Group className="d-flex justify-content-end mt-2">
        <Button
          variant="primary"
          onClick={handleDeploy}
          disabled={!isOnline || !selectedRelease || isDeploying}
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
