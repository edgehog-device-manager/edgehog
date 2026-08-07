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

import React from "react";

interface Props {
  children?: React.ReactNode;
  image?: string;
  title?: string | JSX.Element;
}

const ResultWrapper = ({ children, image, title }: Props) => {
  return (
    <div className="p-5 d-flex justify-content-center align-items-center">
      {image && <img alt="Result" width="250em" src={image} />}
      <div className={image ? "ms-5" : "text-center"}>
        {title && <h4>{title}</h4>}
        {children}
      </div>
    </div>
  );
};

// TODO: define default image for the EmptyList case
const EmptyList = ({ image = undefined, ...restProps }: Props) => (
  <ResultWrapper image={image} {...restProps} />
);

// TODO: define default image for the NotFound case
const NotFound = ({ image = undefined, ...restProps }: Props) => (
  <ResultWrapper image={image} {...restProps} />
);

const Result = {
  EmptyList,
  NotFound,
};

export default Result;
