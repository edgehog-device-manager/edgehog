/*
  This file is part of Edgehog.

  Copyright 2023-2024 SECO Mind Srl

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

import { Link, Route } from "Navigation";
import ApplicationAccountsTable from "components/ApplicationAccountsTable";
import Button from "components/Button";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import { FunctionComponent, Suspense } from "react";
import { Spinner } from "react-bootstrap";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";

interface Props {}
interface AccountTemp {
  label: string;
  username: string;
}

const mockAccounts: Array<AccountTemp> = [
  { label: "Amico", username: "amico123" },
  { label: "Profeta", username: "dottorando_23423" },
];

const { LoadingError, Header, Main } = Page;
const { EmptyList } = Result;
const { applicationAccountsNew } = Route;

const ApplicationAccounts: FunctionComponent<Props> = () => (
  <Suspense
    fallback={
      <Center data-testid="page-loading">
        <Spinner />
      </Center>
    }
  >
    <ErrorBoundary
      FallbackComponent={({ resetErrorBoundary }) => (
        <Center data-testid="page-error">
          <LoadingError onRetry={resetErrorBoundary} />
        </Center>
      )}
      // onReset={fetchCreateUpdateCampaignOptions}
    >
      <Page>
        <Header
          title={<FormattedMessage id="pages.ApplicationAccounts.title" />}
        >
          <Button as={Link} route={applicationAccountsNew}>
            <FormattedMessage id="pages.ApplicationAccount.createButton" />
          </Button>
        </Header>

        <Main>
          {mockAccounts.length === 0 ? (
            <EmptyList
              title={
                <FormattedMessage id="pages.SystemModels.noSystemModels.title" />
              }
            >
              <FormattedMessage
                id="pages.SystemModels.noSystemModels.message"
                defaultMessage="You haven't created any system model yet."
              />
            </EmptyList>
          ) : (
            <ApplicationAccountsTable data={mockAccounts} />
          )}

          {/* <UpdateCampaignWrapper
            getCreateUpdateCampaignOptionsQuery={
              getCreateUpdateCampaignOptionsQuery
            }
          /> */}
        </Main>
      </Page>
      {/* {getCreateUpdateCampaignOptionsQuery && (
            <Page>
              <Page.Header
                title={
                  <FormattedMessage
                    id="pages.UpdateCampaignCreate.title"
                    defaultMessage="Create Update Campaign"
                  />
                }
              />
              <Page.Main>
                <UpdateCampaignWrapper
                  getCreateUpdateCampaignOptionsQuery={
                    getCreateUpdateCampaignOptionsQuery
                  }
                />
              </Page.Main>
            </Page>
          )} */}
    </ErrorBoundary>
  </Suspense>
);

export default ApplicationAccounts;

// import type { ReactNode } from "react";
// import { Suspense, useCallback, useEffect, useState } from "react";
// import { ErrorBoundary } from "react-error-boundary";
// import { FormattedMessage } from "react-intl";
// import type { PreloadedQuery } from "react-relay/hooks";
// import {
//   graphql,
//   useMutation,
//   usePreloadedQuery,
//   useQueryLoader,
// } from "react-relay/hooks";

// import type { UpdateCampaignCreate_createUpdateCampaign_Mutation } from "api/__generated__/UpdateCampaignCreate_createUpdateCampaign_Mutation.graphql";
// import type {
//   UpdateCampaignCreate_getOptions_Query,
//   UpdateCampaignCreate_getOptions_Query$data,
// } from "api/__generated__/UpdateCampaignCreate_getOptions_Query.graphql";
// import Alert from "components/Alert";
// import Button from "components/Button";
// import Center from "components/Center";
// import Page from "components/Page";
// import Result from "components/Result";
// import Spinner from "components/Spinner";
// import type { UpdateCampaignData } from "forms/CreateUpdateCampaign";
// import CreateUpdateCampaignForm from "forms/CreateUpdateCampaign";
// import { Link, Route, useNavigate } from "Navigation";

// const GET_CREATE_UPDATE_CAMPAIGN_OPTIONS_QUERY = graphql`
//   query UpdateCampaignCreate_getOptions_Query {
//     baseImageCollections {
//       __typename
//     }
//     updateChannels {
//       __typename
//     }
//     ...CreateUpdateCampaign_OptionsFragment
//   }
// `;

// const CREATE_UPDATE_CAMPAIGN_MUTATION = graphql`
//   mutation UpdateCampaignCreate_createUpdateCampaign_Mutation(
//     $input: CreateUpdateCampaignInput!
//   ) {
//     createUpdateCampaign(input: $input) {
//       result {
//         id
//       }
//     }
//   }
// `;

// type UpdateCampaignProps = {
//   updateCampaignOptions: UpdateCampaignCreate_getOptions_Query$data;
// };

// const UpdateCampaign = ({ updateCampaignOptions }: UpdateCampaignProps) => {
//   const navigate = useNavigate();
//   const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);

//   const [createUpdateCampaign, isCreatingUpdateCampaign] =
//     useMutation<UpdateCampaignCreate_createUpdateCampaign_Mutation>(
//       CREATE_UPDATE_CAMPAIGN_MUTATION,
//     );

//   const handleCreateUpdateCampaign = useCallback(
//     (updateCampaign: UpdateCampaignData) => {
//       createUpdateCampaign({
//         variables: { input: updateCampaign },
//         onCompleted(data, errors) {
//           if (data.createUpdateCampaign?.result) {
//             const updateCampaignId = data.createUpdateCampaign.result.id;
//             navigate({
//               route: Route.updateCampaignsEdit,
//               params: { updateCampaignId },
//             });
//           }
//           if (errors) {
//             const errorFeedback = errors
//               .map(({ fields, message }) =>
//                 fields.length ? `${fields.join(" ")} ${message}` : message,
//               )
//               .join(". \n");
//             return setErrorFeedback(errorFeedback);
//           }
//         },
//         onError() {
//           setErrorFeedback(
//             <FormattedMessage
//               id="pages.UpdateCampaignCreate.creationErrorFeedback"
//               defaultMessage="Could not create the Update Campaign, please try again."
//             />,
//           );
//         },
//         updater(store, data) {
//           if (!data?.createUpdateCampaign?.result) {
//             return;
//           }

//           const updateCampaign = store
//             .getRootField("createUpdateCampaign")
//             .getLinkedRecord("result");
//           const root = store.getRoot();

//           const updateCampaigns = root.getLinkedRecords("updateCampaigns");
//           if (updateCampaigns) {
//             root.setLinkedRecords(
//               [...updateCampaigns, updateCampaign],
//               "updateCampaigns",
//             );
//           }
//         },
//       });
//     },
//     [createUpdateCampaign, navigate],
//   );

//   return (
//     <>
//       <Alert
//         show={!!errorFeedback}
//         variant="danger"
//         onClose={() => setErrorFeedback(null)}
//         dismissible
//       >
//         {errorFeedback}
//       </Alert>
//       <CreateUpdateCampaignForm
//         updateCampaignOptionsRef={updateCampaignOptions}
//         onSubmit={handleCreateUpdateCampaign}
//         isLoading={isCreatingUpdateCampaign}
//       />
//     </>
//   );
// };

// const NoBaseImageCollections = () => (
//   <Result.EmptyList
//     title={
//       <FormattedMessage
//         id="pages.UpdateCampaignCreate.noBaseImageCollection.title"
//         defaultMessage="You haven't created any Base Image Collection yet"
//       />
//     }
//   >
//     <p>
//       <FormattedMessage
//         id="pages.UpdateCampaignCreate.noBaseImageCollection.message"
//         defaultMessage="You need at least one Base Image Collection with Base Image to create an Update Campaign"
//       />
//     </p>
//     <Button as={Link} route={Route.baseImageCollectionsNew}>
//       <FormattedMessage
//         id="pages.UpdateCampaignCreate.noBaseImageCollection.createButton"
//         defaultMessage="Create Base Image Collection"
//       />
//     </Button>
//   </Result.EmptyList>
// );

// const NoUpdateChannels = () => (
//   <Result.EmptyList
//     title={
//       <FormattedMessage
//         id="pages.UpdateCampaignCreate.noUpdateChannel.title"
//         defaultMessage="You haven't created any Update Channel yet"
//       />
//     }
//   >
//     <p>
//       <FormattedMessage
//         id="pages.UpdateCampaignCreate.noUpdateChannel.message"
//         defaultMessage="You need at least one Update Channel to create an Update Campaign"
//       />
//     </p>
//     <Button as={Link} route={Route.updateChannelsNew}>
//       <FormattedMessage
//         id="pages.UpdateCampaignCreate.noUpdateChannel.createButton"
//         defaultMessage="Create Update Channel"
//       />
//     </Button>
//   </Result.EmptyList>
// );

// type UpdateCampaignWrapperProps = {
//   getCreateUpdateCampaignOptionsQuery: PreloadedQuery<UpdateCampaignCreate_getOptions_Query>;
// };

// const UpdateCampaignWrapper = ({
//   getCreateUpdateCampaignOptionsQuery,
// }: UpdateCampaignWrapperProps) => {
//   const updateCampaignOptions = usePreloadedQuery(
//     GET_CREATE_UPDATE_CAMPAIGN_OPTIONS_QUERY,
//     getCreateUpdateCampaignOptionsQuery,
//   );
//   const { baseImageCollections, updateChannels } = updateCampaignOptions;

//   if (baseImageCollections.length === 0) {
//     return <NoBaseImageCollections />;
//   }
//   if (updateChannels.length === 0) {
//     return <NoUpdateChannels />;
//   }

//   return <UpdateCampaign updateCampaignOptions={updateCampaignOptions} />;
// };

// const UpdateCampaignCreatePage = () => {
//   const [getCreateUpdateCampaignOptionsQuery, getCreateUpdateCampaignOptions] =
//     useQueryLoader<UpdateCampaignCreate_getOptions_Query>(
//       GET_CREATE_UPDATE_CAMPAIGN_OPTIONS_QUERY,
//     );

//   const fetchCreateUpdateCampaignOptions = useCallback(
//     () => getCreateUpdateCampaignOptions({}, { fetchPolicy: "network-only" }),
//     [getCreateUpdateCampaignOptions],
//   );

//   useEffect(fetchCreateUpdateCampaignOptions, [
//     fetchCreateUpdateCampaignOptions,
//   ]);

//   return (
//     <Suspense
//       fallback={
//         <Center data-testid="page-loading">
//           <Spinner />
//         </Center>
//       }
//     >
//       <ErrorBoundary
//         FallbackComponent={(props) => (
//           <Center data-testid="page-error">
//             <Page.LoadingError onRetry={props.resetErrorBoundary} />
//           </Center>
//         )}
//         onReset={fetchCreateUpdateCampaignOptions}
//       >
//         Application Account
//         {/* {getCreateUpdateCampaignOptionsQuery && (
//           <Page>
//             <Page.Header
//               title={
//                 <FormattedMessage
//                   id="pages.UpdateCampaignCreate.title"
//                   defaultMessage="Create Update Campaign"
//                 />
//               }
//             />
//             <Page.Main>
//               <UpdateCampaignWrapper
//                 getCreateUpdateCampaignOptionsQuery={
//                   getCreateUpdateCampaignOptionsQuery
//                 }
//               />
//             </Page.Main>
//           </Page>
//         )} */}
//       </ErrorBoundary>
//     </Suspense>
//   );
// };

// export default UpdateCampaignCreatePage;
