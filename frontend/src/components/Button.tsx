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

import { ComponentProps } from "react";
import RNButton from "react-bootstrap/Button";

// Define the 'as' prop with correct types
// See issue: https://github.com/react-bootstrap/react-bootstrap/issues/6103
type RNButtonProps = ComponentProps<typeof RNButton>;
type Props = Omit<RNButtonProps, "as"> & {
  as?: "button" | "a" | React.ElementType;
};

const Button = (props: Props) => (
  // @ts-expect-error wrong types
  <RNButton {...props} />
);

export default Button;
