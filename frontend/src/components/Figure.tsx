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

import React, { useCallback, useEffect, useState } from "react";
import RBFigure from "react-bootstrap/Figure";

const placeholderImage =
  "data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 500 500' style='background-color:%23f8f8f8'%3e%3c/svg%3e";

interface Props {
  alt?: string;
  className?: string;
  src?: string;
}

const Figure = ({ alt, className = "", src }: Props) => {
  const [imageSrc, setImageSrc] = useState(src || placeholderImage);

  const handleError = useCallback(() => {
    setImageSrc(placeholderImage);
  }, []);

  useEffect(() => {
    setImageSrc(src || placeholderImage);
  }, [src]);

  return (
    <RBFigure className={"w-100 " + className}>
      <RBFigure.Image
        alt={alt}
        className="rounded border"
        fluid
        src={imageSrc}
        onError={handleError}
      />
    </RBFigure>
  );
};

export default Figure;
