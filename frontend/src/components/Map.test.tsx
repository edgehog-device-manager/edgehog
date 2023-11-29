/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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

import { expect, it } from "vitest";
import userEvent from "@testing-library/user-event";
import { render, screen } from "@testing-library/react";

import Map from "./Map";

it("shows popup after click on marker", async () => {
  const popupContent = "Popup Message";

  render(<Map latitude={0} longitude={0} popup={popupContent} />);
  expect(screen.queryByText(popupContent)).not.toBeInTheDocument();

  const marker = screen.getByAltText("Marker");
  expect(marker).toBeInTheDocument();

  // Map component uses scrollTo method before popup render
  globalThis.scrollTo = () => {};

  await userEvent.click(marker);
  expect(screen.getByText(popupContent)).toBeInTheDocument();
});
