/*
  This file is part of Edgehog.

  Copyright 2022-2023 SECO Mind Srl

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

import { defineMessages, FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import Col from "react-bootstrap/Col";
import Nav from "react-bootstrap/Nav";
import Row from "react-bootstrap/Row";
import Tab from "react-bootstrap/Tab";

import Form from "components/Form";
import Result from "components/Result";
import Stack from "components/Stack";

import type {
  CellularConnectionTabs_cellularConnection$data,
  CellularConnectionTabs_cellularConnection$key,
  ModemRegistrationStatus,
  ModemTechnology,
} from "api/__generated__/CellularConnectionTabs_cellularConnection.graphql";

const registrationStatusMessages = defineMessages<ModemRegistrationStatus>({
  NOT_REGISTERED: {
    id: "modem.RegistrationStatus.NotRegistered",
    defaultMessage: "Not Registered",
  },
  REGISTERED: {
    id: "modem.RegistrationStatus.Registered",
    defaultMessage: "Registered",
  },
  REGISTRATION_DENIED: {
    id: "modem.RegistrationStatus.RegistrationDenied",
    defaultMessage: "Registration denied",
  },
  REGISTERED_ROAMING: {
    id: "modem.RegistrationStatus.RegisteredRoaming",
    defaultMessage: "Registered, roaming",
  },
  SEARCHING_OPERATOR: {
    id: "modem.RegistrationStatus.SearchingOperator",
    defaultMessage: "Searching an operator to register to",
  },
  UNKNOWN: {
    id: "modem.RegistrationStatus.Unknown",
    defaultMessage: "Unknown",
  },
});

const technologyMessages = defineMessages<ModemTechnology>({
  EUTRAN: {
    id: "modem.technology.EUTRAN",
    defaultMessage: "E-UTRAN",
  },
  GSM: {
    id: "modem.technology.GSM",
    defaultMessage: "GSM",
  },
  GSM_COMPACT: {
    id: "modem.technology.GSM_COMPACT",
    defaultMessage: "GSM Compact",
  },
  GSM_EGPRS: {
    id: "modem.technology.GSM_EGPRS",
    defaultMessage: "GSM with EGPRS",
  },
  UTRAN: {
    id: "modem.technology.UTRAN",
    defaultMessage: "UTRAN",
  },
  UTRAN_HSDPA: {
    id: "modem.technology.UTRAN_HSDPA",
    defaultMessage: "UTRAN with HSDPA",
  },
  UTRAN_HSDPA_HSUPA: {
    id: "modem.technology.UTRAN_HSDPA_HSUPA",
    defaultMessage: "UTRAN with HSDPA and HSUPA",
  },
  UTRAN_HSUPA: {
    id: "modem.technology.UTRAN_HSUPA",
    defaultMessage: "UTRAN with HSUPA",
  },
});

const CELLULAR_CONNECTION_TABS_FRAGMENT = graphql`
  fragment CellularConnectionTabs_cellularConnection on Device {
    cellularConnection {
      apn
      carrier
      cellId
      imei
      imsi
      localAreaCode
      mobileCountryCode
      mobileNetworkCode
      registrationStatus
      rssi
      slot
      technology
    }
  }
`;

type Modems = NonNullable<
  CellularConnectionTabs_cellularConnection$data["cellularConnection"]
>;
type Modem = Modems[number];

const buildModemEventKey = (modem: Modem) => `modem-tab-${modem.slot}`;

const ModemNavItem = ({ modem }: { modem: Modem }) => {
  const { slot } = modem;
  return (
    <Nav.Item>
      <Nav.Link eventKey={buildModemEventKey(modem)}>{slot}</Nav.Link>
    </Nav.Item>
  );
};

const FormRow: (params: {
  id: string;
  label: JSX.Element;
  children: JSX.Element;
}) => JSX.Element = ({ id, label, children }) => (
  <Form.Group as={Row} controlId={id}>
    <Form.Label column sm={3}>
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

const ModemTab = ({ modem }: { modem: Modem }) => {
  const intl = useIntl();
  const { slot } = modem;
  return (
    <Tab.Pane eventKey={buildModemEventKey(modem)}>
      <Stack gap={3}>
        {modem.imei != null && (
          <FormRow
            id={`modem-imei-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.IMEI"
                defaultMessage="IMEI"
              />
            }
          >
            <Form.Control type="text" value={modem.imei} readOnly />
          </FormRow>
        )}
        {modem.imsi != null && (
          <FormRow
            id={`modem-imsi-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.IMSI"
                defaultMessage="IMSI"
              />
            }
          >
            <Form.Control type="text" value={modem.imsi} readOnly />
          </FormRow>
        )}
        {modem.apn != null && (
          <FormRow
            id={`modem-apn-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.APN"
                defaultMessage="APN"
              />
            }
          >
            <Form.Control type="text" value={modem.apn} readOnly />
          </FormRow>
        )}
        {modem.carrier != null && (
          <FormRow
            id={`modem-carrier-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.Carrier"
                defaultMessage="Carrier"
              />
            }
          >
            <Form.Control type="text" value={modem.carrier} readOnly />
          </FormRow>
        )}
        {modem.registrationStatus != null && (
          <FormRow
            id={`modem-registrationStatus-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.RegistrationStatus"
                defaultMessage="Registration Status"
              />
            }
          >
            <Form.Control
              type="text"
              value={intl.formatMessage(
                registrationStatusMessages[modem.registrationStatus]
              )}
              readOnly
            />
          </FormRow>
        )}
        {modem.technology != null && (
          <FormRow
            id={`modem-technology-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.technology"
                defaultMessage="Technology"
              />
            }
          >
            <Form.Control
              type="text"
              value={intl.formatMessage(technologyMessages[modem.technology])}
              readOnly
            />
          </FormRow>
        )}
        {modem.rssi != null && (
          <FormRow
            id={`modem-rssi-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.RSSI"
                defaultMessage="RSSI"
              />
            }
          >
            <Form.Control type="text" value={modem.rssi} readOnly />
          </FormRow>
        )}
        {modem.cellId != null && (
          <FormRow
            id={`modem-cellId-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.CellID"
                defaultMessage="Cell ID"
              />
            }
          >
            <Form.Control type="text" value={modem.cellId} readOnly />
          </FormRow>
        )}
        {modem.localAreaCode != null && (
          <FormRow
            id={`modem-localAreaCode-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.LocalAreaCode"
                defaultMessage="Local Area Code"
              />
            }
          >
            <Form.Control type="text" value={modem.localAreaCode} readOnly />
          </FormRow>
        )}
        {modem.mobileNetworkCode != null && (
          <FormRow
            id={`modem-mobileNetworkCode-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.MobileNetworkCode"
                defaultMessage="Mobile Network Code"
              />
            }
          >
            <Form.Control
              type="text"
              value={modem.mobileNetworkCode}
              readOnly
            />
          </FormRow>
        )}
        {modem.mobileCountryCode != null && (
          <FormRow
            id={`modem-mobileCountryCode-${slot}`}
            label={
              <FormattedMessage
                id="components.CellularConnectionTabs.Modem.MobileCountryCode"
                defaultMessage="Mobile Country Code"
              />
            }
          >
            <Form.Control
              type="text"
              value={modem.mobileCountryCode}
              readOnly
            />
          </FormRow>
        )}
      </Stack>
    </Tab.Pane>
  );
};

interface Props {
  deviceRef: CellularConnectionTabs_cellularConnection$key;
}

const CellularConnectionTabs = ({ deviceRef }: Props) => {
  const { cellularConnection } = useFragment(
    CELLULAR_CONNECTION_TABS_FRAGMENT,
    deviceRef
  );

  if (!cellularConnection || cellularConnection.length === 0) {
    return (
      <Result.EmptyList
        title={
          <FormattedMessage
            id="pages.Device.DeviceCellularConnectionTab.noModems.title"
            defaultMessage="No modem"
          />
        }
      >
        <FormattedMessage
          id="pages.Device.DeviceCellularConnectionTab.noModems.message"
          defaultMessage="The device has not detected any modems yet."
        />
      </Result.EmptyList>
    );
  }

  return (
    <Tab.Container defaultActiveKey={buildModemEventKey(cellularConnection[0])}>
      <Row>
        <Col sm={2} md={3}>
          <Nav variant="pills" className="flex-column">
            {cellularConnection.map((modem) => (
              <ModemNavItem
                modem={modem}
                key={`modem-nav-item-${modem.slot}`}
              />
            ))}
          </Nav>
        </Col>
        <Col sm={10} md={9}>
          <Tab.Content>
            {cellularConnection.map((modem) => (
              <ModemTab modem={modem} key={`modem-tab-pane-${modem.slot}`} />
            ))}
          </Tab.Content>
        </Col>
      </Row>
    </Tab.Container>
  );
};

export default CellularConnectionTabs;
