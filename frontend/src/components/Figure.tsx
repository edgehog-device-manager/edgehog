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
