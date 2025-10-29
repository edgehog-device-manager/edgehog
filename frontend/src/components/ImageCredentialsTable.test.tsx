/*
  This file is part of Edgehog.

  Copyright 2024-2025 SECO Mind Srl

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

import { screen } from "@testing-library/react";
import { createMockEnvironment } from "relay-test-utils";
import { renderWithProviders } from "setupTests";
import { expect, it } from "vitest";

import type { ImageCredentialsTable_imageCredentials_Test_Query } from "api/__generated__/ImageCredentialsTable_imageCredentials_Test_Query.graphql";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";
import ImageCredentialsTable from "./ImageCredentialsTable";

const IMAGE_CREDENTIALS_TEST_QUERY = graphql`
  query ImageCredentialsTable_imageCredentials_Test_Query(
    $first: Int
    $after: String
    $filter: ImageCredentialsFilterInput = {}
  ) {
    ...ImageCredentialsTable_imageCredentials_Fragment
      @arguments(filter: $filter)
  }
`;

type ImageCredentialData = {
  id: string;
  label: string;
  username: string;
};

interface Data {
  edges: { node: ImageCredentialData }[];
}

const data: Data = {
  edges: [
    {
      node: {
        id: "IC-ID",
        label: "IC Label",
        username: "IC Username",
      },
    },
  ],
};

const labels = {
  label: "Label",
  username: "Username",
};

const ComponentWithQuery = () => {
  const listImageCredentialsRef =
    useLazyLoadQuery<ImageCredentialsTable_imageCredentials_Test_Query>(
      IMAGE_CREDENTIALS_TEST_QUERY,
      {},
    );

  return (
    <ImageCredentialsTable listImageCredentialsRef={listImageCredentialsRef} />
  );
};

const renderComponent = (listImageCredentials: Data) => {
  const relayEnvironment = createMockEnvironment();
  relayEnvironment.mock.queueOperationResolver((_operation) => ({
    data: { listImageCredentials },
  }));
  renderWithProviders(<ComponentWithQuery />, { relayEnvironment });
};

it("renders column headers", () => {
  renderComponent({ edges: [] });
  expect(
    screen.getByRole("columnheader", { name: labels.label }),
  ).toBeVisible();
  expect(
    screen.getByRole("columnheader", { name: labels.username }),
  ).toBeVisible();
});

it("renders column headers", () => {
  renderComponent({ edges: [] });
  expect(
    screen.getByRole("columnheader", { name: labels.label }),
  ).toBeVisible();
  expect(
    screen.getByRole("columnheader", { name: labels.username }),
  ).toBeVisible();
});

it("renders Image Credentials data", () => {
  renderComponent(data);

  const record = data.edges[0];

  expect(screen.getByRole("cell", { name: record.node.label })).toBeVisible();
  expect(screen.getByRole("link", { name: record.node.label })).toHaveAttribute(
    "href",
    `/image-credentials/${record.node.id}/edit`,
  );
  expect(
    screen.getByRole("cell", { name: record.node.username }),
  ).toBeVisible();
});

it("renders Image Credentials data in correct columns", () => {
  renderComponent(data);

  const record = data.edges[0];

  const columns = screen.getAllByRole("columnheader");
  const cells = screen.getAllByRole("cell");

  expect(columns).toHaveLength(2);
  expect(cells).toHaveLength(2);

  expect(columns[0]).toHaveTextContent(labels.label);
  expect(cells[0]).toHaveTextContent(record.node.label);

  expect(columns[1]).toHaveTextContent(labels.username);
  expect(cells[1]).toHaveTextContent(record.node.username);
});
