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
*/

import React from "react";

import { renderWithProviders } from "setupTests";
import LastSeen from "./LastSeen";

it("displays Now for a device that is connected", () => {
  const props = {
    lastConnection: "2021-11-08T15:43:34.706Z",
    lastDisconnection: null,
    online: true,
  };
  const { container } = renderWithProviders(<LastSeen {...props} />);
  expect(container).toHaveTextContent("Now");
});

it("displays Never for a device that never connected", () => {
  const props = {
    lastConnection: null,
    lastDisconnection: null,
    online: false,
  };
  const { container } = renderWithProviders(<LastSeen {...props} />);
  expect(container).toHaveTextContent("Never");
});

it("displays date of last disconnection for a device that was once connected", () => {
  const props = {
    lastConnection: "2021-11-05T15:43:34.706Z",
    lastDisconnection: "2021-11-08T15:43:34.706Z",
    online: false,
  };
  const { container } = renderWithProviders(<LastSeen {...props} />);
  expect(container).toHaveTextContent("November 8, 2021, 3:43 PM");
});
