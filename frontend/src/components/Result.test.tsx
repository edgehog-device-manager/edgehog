/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind

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
import { render } from "@testing-library/react";

import Result from "./Result";

it("renders NotFound correctly", () => {
  const imageSrc =
    "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";
  const { container } = render(<Result.NotFound image={imageSrc} />);
  const image = container.querySelector("img");
  expect(image).toBeInTheDocument();
  expect(image).toHaveAttribute("src", imageSrc);
});
