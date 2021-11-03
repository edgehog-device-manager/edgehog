import { FormattedMessage } from "react-intl";

import Button from "components/Button";

type PageProps = {
  children?: React.ReactNode;
};

const Page = ({ children }: PageProps) => {
  return (
    <div data-testid="page" className="p-4">
      {children}
    </div>
  );
};

type PageHeaderProps = {
  title?: React.ReactNode;
};

const PageHeader = ({ title }: PageHeaderProps) => {
  return (
    <header className="d-flex justify-content-between align-items-center">
      {title && <h2 data-testid="page-title">{title}</h2>}
    </header>
  );
};

type PageMainProps = {
  children?: React.ReactNode;
};

const PageMain = ({ children }: PageMainProps) => {
  return <main className="mt-4">{children}</main>;
};

type PageLoadingErrorProps = {
  onRetry?: () => void;
};

const PageLoadingError = ({ onRetry }: PageLoadingErrorProps) => {
  return (
    <div className="d-flex flex-column">
      <FormattedMessage
        id="components.Page.loadingError.feedback"
        defaultMessage="The page couldn't load."
      />
      {onRetry && (
        <Button onClick={onRetry} className="mt-3 m-auto">
          <FormattedMessage
            id="components.Page.loadingError.retryButton"
            defaultMessage="Try again"
          />
        </Button>
      )}
    </div>
  );
};

Page.Header = PageHeader;
Page.Main = PageMain;
Page.LoadingError = PageLoadingError;

export default Page;
