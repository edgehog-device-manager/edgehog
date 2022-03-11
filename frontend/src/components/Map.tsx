/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

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

import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import "./Map.scss";

type Props = {
  latitude: number;
  longitude: number;
  popup?: React.ReactNode;
};

const Map = ({ latitude, longitude, popup, ...props }: Props) => {
  return (
    <MapContainer
      className="map"
      key={`${latitude}-${longitude}`}
      center={[latitude, longitude]}
      zoom={13}
      scrollWheelZoom
      {...props}
    >
      <TileLayer
        attribution='&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Marker position={[latitude, longitude]}>
        {!!popup && <Popup>{popup}</Popup>}
      </Marker>
    </MapContainer>
  );
};

export default Map;
