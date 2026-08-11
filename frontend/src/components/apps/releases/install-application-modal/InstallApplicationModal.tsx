/*
 * This file is part of Edgehog.
 *
 * Copyright 2024-2026 SECO Mind Srl
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

import React, { useCallback, useState, useMemo } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useLazyLoadQuery, useMutation } from "react-relay/hooks";
import { SingleValue } from "react-select";

import type { InstallApplicationModal_GetApplicationsWithReleases_Query } from "@/api/__generated__/InstallApplicationModal_GetApplicationsWithReleases_Query.graphql";
import type { InstallApplicationModal_DeployRelease_Mutation } from "@/api/__generated__/InstallApplicationModal_DeployRelease_Mutation.graphql";
import { useNavigate, Route } from "@/Navigation";
import Select from "@/components/ui/select/Select";
import { FormRow } from "@/components/ui/form-row/FormRow";
import ConfirmModal from "@/components/ui/confirm-modal/ConfirmModal";

const GET_APPLICATIONS_WITH_RELEASES_QUERY = graphql`
  query InstallApplicationModal_GetApplicationsWithReleases_Query(
    $filter: ApplicationFilterInput = {}
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
  mutation InstallApplicationModal_DeployRelease_Mutation(
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

type InstallApplicationModalProps = {
  open: boolean;
  onToggleModal: (show: boolean) => void;
  deviceId: string;
  systemModelName: string | undefined;
  isOnline: boolean;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
};

type SelectOption = {
  value: string;
  label: string;
  disabled: boolean;
};

const InstallApplicationModal = ({
  open,
  onToggleModal,
  deviceId,
  systemModelName,
  isOnline,
  setErrorFeedback,
}: InstallApplicationModalProps) => {
  const intl = useIntl();
  const navigate = useNavigate();

  const [selectedApp, setSelectedApp] = useState<string | null>(null);
  const [selectedRelease, setSelectedRelease] = useState<string | null>(null);

  const data =
    useLazyLoadQuery<InstallApplicationModal_GetApplicationsWithReleases_Query>(
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

  const applicationEdges = useMemo(
    () => data.applications?.edges ?? [],
    [data.applications?.edges],
  );

  const applicationOptions: SelectOption[] = useMemo(() => {
    return applicationEdges.map((app) => ({
      value: app.node.id,
      label: app.node.name,
      disabled: false,
    }));
  }, [applicationEdges]);

  const selectedApplicationOption = useMemo(() => {
    return (
      applicationOptions.find((option) => option.value === selectedApp) || null
    );
  }, [applicationOptions, selectedApp]);

  const releaseOptions: SelectOption[] = useMemo(() => {
    if (!selectedApp || !applicationEdges) return [];

    const selectedApplication = applicationEdges.find(
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
  }, [selectedApp, applicationEdges, systemModelName]);

  const selectedReleaseOption = useMemo(() => {
    return (
      releaseOptions.find((option) => option.value === selectedRelease) || null
    );
  }, [releaseOptions, selectedRelease]);

  const [deployRelease, isDeploying] =
    useMutation<InstallApplicationModal_DeployRelease_Mutation>(
      DEPLOY_RELEASE_MUTATION,
    );

  const handleAppChange = (option: SingleValue<SelectOption>) => {
    if (!isOnline) {
      setErrorFeedback(
        <FormattedMessage
          id="components.apps.releases.install-application-modal.InstallApplicationModal.deviceOfflineError"
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

  const resetSelections = useCallback(() => {
    setSelectedApp(null);
    setSelectedRelease(null);
  }, []);

  const handleCancel = useCallback(() => {
    resetSelections();
    onToggleModal(false);
  }, [resetSelections, onToggleModal]);

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
          resetSelections();
          setErrorFeedback(null);
          onToggleModal(false);

          const deploymentId = data?.deployRelease?.result?.id;

          if (deploymentId) {
            return navigate({
              route: Route.deploymentEdit,
              params: { deviceId, deploymentId },
            });
          }
        },
        onError: () => {
          setErrorFeedback(
            <FormattedMessage
              id="components.apps.releases.install-application-modal.InstallApplicationModal.deployErrorFeedback"
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
    resetSelections,
    setErrorFeedback,
    onToggleModal,
    navigate,
  ]);

  return (
    <ConfirmModal
      title={
        <FormattedMessage
          id="components.apps.releases.install-application-modal.InstallApplicationModal.title"
          defaultMessage="Install Application"
        />
      }
      confirmLabel={
        <FormattedMessage
          id="components.apps.releases.install-application-modal.InstallApplicationModal.deployButton"
          defaultMessage="Deploy"
        />
      }
      show={open}
      onCancel={handleCancel}
      onConfirm={handleDeploy}
      disabled={!isOnline || !selectedRelease}
      isConfirming={isDeploying}
    >
      <div className="d-flex flex-column gap-2">
        <FormRow
          id="select-application"
          label={intl.formatMessage({
            id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectApplication",
            defaultMessage: "Select Application",
          })}
        >
          <Select
            value={selectedApplicationOption}
            onChange={handleAppChange}
            options={applicationOptions}
            isClearable
            placeholder={intl.formatMessage({
              id: "components.apps.releases.install-application-modal.InstallApplicationModal.searchPlaceholder",
              defaultMessage: "Search or select an application...",
            })}
            noOptionsMessage={({ inputValue }) =>
              inputValue
                ? intl.formatMessage(
                    {
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.noApplicationsFoundMatching",
                      defaultMessage:
                        'No applications found matching "{inputValue}"',
                    },
                    { inputValue },
                  )
                : intl.formatMessage({
                    id: "components.apps.releases.install-application-modal.InstallApplicationModal.noApplicationsAvailable",
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
        </FormRow>

        <FormRow
          id="select-release"
          label={intl.formatMessage({
            id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectRelease",
            defaultMessage: "Select Release",
          })}
        >
          <Select
            value={selectedReleaseOption}
            onChange={handleReleaseChange}
            options={releaseOptions}
            isClearable
            placeholder={intl.formatMessage({
              id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectARelease",
              defaultMessage: "Select a release",
            })}
            noOptionsMessage={({ inputValue }) =>
              inputValue
                ? intl.formatMessage(
                    {
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.noReleasesFoundMatching",
                      defaultMessage:
                        'No releases found matching "{inputValue}"',
                    },
                    { inputValue },
                  )
                : selectedApp
                  ? intl.formatMessage({
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.noReleasesAvailable",
                      defaultMessage:
                        "No releases available for this application",
                    })
                  : intl.formatMessage({
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectApplicationFirst",
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
        </FormRow>
      </div>
    </ConfirmModal>
  );
};

export default InstallApplicationModal;
