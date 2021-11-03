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

// TODO: define default image for the NotFound case
const NotFound = ({ image = undefined, ...restProps }: Props) => (
  <ResultWrapper image={image} {...restProps} />
);

const Result = {
  NotFound,
};

export default Result;
