/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import Button from "react-bootstrap/Button";
import Image from "react-bootstrap/Image";

import Icon from "@/components/Icon";
import assets from "@/assets";

type SidebarHeaderProps = {
  isDesktopCollapsed: boolean;
  isMobileMenuOpen: boolean;
  onToggleCollapse: () => void;
};

const SidebarHeader = ({
  isDesktopCollapsed,
  isMobileMenuOpen,
  onToggleCollapse,
}: SidebarHeaderProps) => {
  if (isMobileMenuOpen) {
    return null;
  }
  return (
    <div className="sidebar-header d-flex align-items-center justify-content-between px-4">
      <Image
        alt="Clea Edgehog Logo"
        src={isDesktopCollapsed ? assets.images.logo : assets.images.brand}
        className="sidebar-brand-img"
      />

      <Button
        variant="light"
        onClick={onToggleCollapse}
        className="sidebar-collapse-toggle d-none d-md-flex align-items-center justify-content-center"
      >
        <Icon
          icon={isDesktopCollapsed ? "anglesRight" : "anglesLeft"}
          className="text-secondary"
        />
      </Button>
    </div>
  );
};

export type { SidebarHeaderProps };

export default SidebarHeader;
