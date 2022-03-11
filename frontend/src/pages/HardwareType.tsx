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

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
} from "react-relay/hooks";
import { FormattedMessage } from "react-intl";
import _ from "lodash";

import type { HardwareType_getHardwareType_Query } from "api/__generated__/HardwareType_getHardwareType_Query.graphql";
import type { HardwareType_updateHardwareType_Mutation } from "api/__generated__/HardwareType_updateHardwareType_Mutation.graphql";
import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateHardwareTypeForm, {
  HardwareTypeData,
} from "forms/UpdateHardwareType";

const GET_HARDWARE_TYPE_QUERY = graphql`
  query HardwareType_getHardwareType_Query($id: ID!) {
    hardwareType(id: $id) {
      id
      name
      handle
      partNumbers
    }
  }
`;

const UPDATE_HARDWARE_TYPE_MUTATION = graphql`
  mutation HardwareType_updateHardwareType_Mutation(
    $input: UpdateHardwareTypeInput!
  ) {
    updateHardwareType(input: $input) {
      hardwareType {
        id
        name
        handle
        partNumbers
      }
    }
  }
`;

interface HardwareTypeContentProps {
  getHardwareTypeQuery: PreloadedQuery<HardwareType_getHardwareType_Query>;
}

const HardwareTypeContent = ({
  getHardwareTypeQuery,
}: HardwareTypeContentProps) => {
  const { hardwareTypeId = "" } = useParams();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const hardwareTypeData = usePreloadedQuery(
    GET_HARDWARE_TYPE_QUERY,
    getHardwareTypeQuery
  );

  const [updateHardwareType, isUpdatingHardwareType] =
    useMutation<HardwareType_updateHardwareType_Mutation>(
      UPDATE_HARDWARE_TYPE_MUTATION
    );

  // TODO: handle readonly type without mapping to mutable type
  const hardwareType = useMemo(
    () =>
      hardwareTypeData.hardwareType && {
        ...hardwareTypeData.hardwareType,
        partNumbers: [...hardwareTypeData.hardwareType.partNumbers],
      },
    [hardwareTypeData.hardwareType]
  );

  const handleUpdateHardwareType = useCallback(
    (hardwareType: HardwareTypeData) => {
      const input = {
        hardwareTypeId,
        ...hardwareType,
      };
      updateHardwareType({
        variables: { input },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
        },
        onError(error) {
          setErrorFeedback(
            <FormattedMessage
              id="pages.HardwareTypeUpdate.creationErrorFeedback"
              defaultMessage="Could not update the hardware type, please try again."
            />
          );
        },
      });
    },
    [updateHardwareType, hardwareTypeId]
  );

  if (!hardwareType) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.HardwareType.hardwareTypeNotFound.title"
            defaultMessage="Hardware type not found."
          />
        }
      >
        <Link route={Route.hardwareTypes}>
          <FormattedMessage
            id="pages.HardwareType.hardwareTypeNotFound.message"
            defaultMessage="Return to the hardware type list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <Page>
      <Page.Header title={hardwareType.name} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <UpdateHardwareTypeForm
          initialData={_.pick(hardwareType, ["name", "handle", "partNumbers"])}
          onSubmit={handleUpdateHardwareType}
          isLoading={isUpdatingHardwareType}
        />
      </Page.Main>
    </Page>
  );
};

const HardwareTypePage = () => {
  const { hardwareTypeId = "" } = useParams();

  const [getHardwareTypeQuery, getHardwareType] =
    useQueryLoader<HardwareType_getHardwareType_Query>(GET_HARDWARE_TYPE_QUERY);

  useEffect(() => {
    getHardwareType({ id: hardwareTypeId });
  }, [getHardwareType, hardwareTypeId]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={(props) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={props.resetErrorBoundary} />
          </Center>
        )}
        onReset={() => {
          getHardwareType({ id: hardwareTypeId });
        }}
      >
        {getHardwareTypeQuery && (
          <HardwareTypeContent getHardwareTypeQuery={getHardwareTypeQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default HardwareTypePage;
