import { FormattedMessage } from "react-intl";

const DevicePage = () => {
  return (
    <div className="p-4">
      <header className="d-flex justify-content-between align-items-center">
        <h2>
          <FormattedMessage id="pages.Device.title" defaultMessage="Device" />
        </h2>
      </header>
      <main className="mt-4"></main>
    </div>
  );
};

export default DevicePage;
