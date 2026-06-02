/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2026 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Image from "react-bootstrap/Image";

import assets from "@/assets";
import Button from "@/components/Button";
import Icon from "@/components/Icon";
import "@/components/Topbar.scss";

interface TopbarProps {
  onToggle?: () => void;
}

const Topbar = ({ onToggle }: TopbarProps) => {
  return (
    <header className="Topbar d-md-none border-bottom p-3 d-flex align-items-center shadow-sm gap-3">
      <Button
        className="btn-light bg-transparent border-0 d-flex align-items-center justify-content-center flex-shrink-0"
        onClick={onToggle}
      >
        <Icon icon="menu" />
      </Button>
      <Image
        src={assets.images.brand}
        alt="Clea Edgehog Logo"
        className="Topbar-brand"
      />
    </header>
  );
};

export default Topbar;
