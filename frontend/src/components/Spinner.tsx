import React from "react";
import BoostrapSpinner from "react-bootstrap/Spinner";

type BoostrapSpinnerProps = React.ComponentProps<typeof BoostrapSpinner>;

type Props = Pick<BoostrapSpinnerProps, "className" | "size" | "variant">;

const Spinner = (props: Props) => {
  return <BoostrapSpinner animation="border" role="status" {...props} />;
};

export default Spinner;
