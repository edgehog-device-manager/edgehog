type Props = React.HTMLAttributes<HTMLDivElement>;

const Center = ({ children, className = "", ...restProps }: Props) => {
  const classNames = [
    "h-100 d-flex flex-column justify-content-center align-items-center",
    className,
  ];

  return (
    <div className={classNames.join(" ")} {...restProps}>
      {children}
    </div>
  );
};

export default Center;
