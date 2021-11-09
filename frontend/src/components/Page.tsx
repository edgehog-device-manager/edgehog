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
  children?: React.ReactNode;
  title?: React.ReactNode;
};

const PageHeader = ({ children, title }: PageHeaderProps) => {
  return (
    <header className="d-flex justify-content-between align-items-center">
      {title && <h2 data-testid="page-title">{title}</h2>}
      {children}
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
