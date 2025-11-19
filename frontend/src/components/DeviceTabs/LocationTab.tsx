/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { graphql, useFragment } from "react-relay/hooks";
import { FormattedDate, FormattedMessage, useIntl } from "react-intl";

import type { LocationTab_location$key } from "api/__generated__/LocationTab_location.graphql";

import Map from "components/Map";
import { Tab } from "components/Tabs";

const DEVICE_LOCATION_FRAGMENT = graphql`
  fragment LocationTab_location on Device {
    capabilities
    position {
      latitude
      longitude
      timestamp
    }
    location {
      formattedAddress
    }
  }
`;

interface DeviceLocationTabProps {
  deviceRef: LocationTab_location$key;
}

const DeviceLocationTab = ({ deviceRef }: DeviceLocationTabProps) => {
  const intl = useIntl();
  const { capabilities, position, location } = useFragment(
    DEVICE_LOCATION_FRAGMENT,
    deviceRef,
  );
  if (!position || !capabilities.includes("GEOLOCATION")) {
    return null;
  }
  return (
    <Tab
      eventKey="device-location-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.LocationTab",
        defaultMessage: "Geolocation",
      })}
    >
      <div className="mt-3">
        <p>
          <FormattedMessage
            id="components.DeviceTabs.LocationTab.lastUpdateAt"
            defaultMessage="Last known location, updated at {date}"
            values={{
              date: (
                <FormattedDate
                  value={new Date(position.timestamp)}
                  year="numeric"
                  month="long"
                  day="numeric"
                  hour="numeric"
                  minute="numeric"
                />
              ),
            }}
          />
        </p>
        <Map
          latitude={position.latitude}
          longitude={position.longitude}
          popup={
            <div>
              {location && <p>{location.formattedAddress}</p>}
              <p>
                {position.latitude}, {position.longitude}
              </p>
            </div>
          }
        />
      </div>
    </Tab>
  );
};

export default DeviceLocationTab;
