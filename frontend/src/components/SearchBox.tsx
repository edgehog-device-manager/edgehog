import React, { useCallback } from "react";
import { useIntl } from "react-intl";
import Form from "react-bootstrap/Form";
import InputGroup from "react-bootstrap/InputGroup";

import Icon from "components/Icon";

interface Props {
  className?: string;
  onChange?: (searchText: string) => void;
}

const SearchBox = ({ className = "", onChange }: Props) => {
  const intl = useIntl();

  const handleChange: React.ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      const searchText = event.target.value;
      onChange && onChange(searchText);
    },
    [onChange]
  );

  return (
    <Form className={`justify-content-end ${className}`}>
      <InputGroup>
        <Form.Control
          className="border-end-0"
          type="search"
          placeholder={intl.formatMessage({
            id: "components.SearchBox.searchPlaceholder",
            defaultMessage: "Search",
            description: "Placeholder for the search input of the SearchBox",
          })}
          onChange={handleChange}
        />
        <InputGroup.Text className="bg-transparent">
          <Icon icon="search" />
        </InputGroup.Text>
      </InputGroup>
    </Form>
  );
};

export default SearchBox;
