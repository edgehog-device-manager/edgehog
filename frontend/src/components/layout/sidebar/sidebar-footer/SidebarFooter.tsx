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

import { FormattedMessage, useIntl } from "react-intl";

import { Route } from "@/Navigation";
import SidebarItem from "@/components/layout/sidebar/sidebar-item/SidebarItem";
import Button from "@/components/ui/button/Button";
import Icon from "@/components/ui/icon/Icon";
import Popover from "@/components/ui/popover/Popover";
import OverlayTrigger from "@/components/ui/overlay-trigger/OverlayTrigger";

type SidebarFooterProps = {
  appName?: string;
  appVersion: string;
  repoUrl?: string;
  docsUrl?: string;
  isCollapsed?: boolean;
};

const SidebarFooter = ({
  appName,
  appVersion,
  repoUrl,
  docsUrl,
  isCollapsed,
}: SidebarFooterProps) => {
  const intl = useIntl();

  const layout = isCollapsed
    ? "flex-column align-items-center"
    : "flex-row justify-content-between w-100";

  const infoPopover = (
    <Popover className="sidebar-footer-popover">
      <Popover.Header as="h3" className="d-flex align-items-center gap-2">
        <span className="sidebar-app-name">{appName}</span>
        <small className="text-secondary opacity-75 fw-normal">
          <FormattedMessage
            id="components.layout.sidebar.sidebar-footer.SidebarFooter.versionLabel"
            defaultMessage="Version {appVersion}"
            values={{ appVersion }}
          />
        </small>
      </Popover.Header>
      <Popover.Body className="d-flex flex-column gap-1 p-2">
        {repoUrl && (
          <a
            href={repoUrl}
            className="sidebar-footer-link d-flex align-items-center gap-2 px-2 py-1 rounded text-decoration-none"
            target="_blank"
            rel="noreferrer"
          >
            <Icon className="text-black flex-shrink-0" icon="github" />
            <FormattedMessage
              id="components.layout.sidebar.sidebar-footer.SidebarFooter.sourceCodeLabel"
              defaultMessage="Source code"
            />
          </a>
        )}

        {docsUrl && (
          <a
            href={docsUrl}
            className="sidebar-footer-link d-flex align-items-center gap-2 px-2 py-1 rounded text-decoration-none"
            target="_blank"
            rel="noreferrer"
          >
            <Icon className="text-black flex-shrink-0" icon="documentation" />
            <FormattedMessage
              id="components.layout.sidebar.sidebar-footer.SidebarFooter.documentationLabel"
              defaultMessage="Documentation"
            />
          </a>
        )}
      </Popover.Body>
    </Popover>
  );

  return (
    <div className="sidebar-footer d-flex align-items-center flex-shrink-0 mb-2 bg-white border-top">
      <div
        className={`sidebar-footer-actions d-flex ${layout}`}
        data-testid="sidebar-footer-actions"
      >
        <div className="sidebar-footer-action-item sidebar-footer-action">
          <OverlayTrigger
            trigger="click"
            rootClose
            placement={isCollapsed ? "right" : "top"}
            overlay={infoPopover}
          >
            <Button
              variant="light"
              className="sidebar-info-button d-flex align-items-center justify-content-center"
              aria-label={intl.formatMessage({
                id: "components.layout.sidebar.sidebar-footer.SidebarFooter.infoLabel",
                defaultMessage: "About",
              })}
            >
              <Icon icon="info" className="sidebar-icon flex-shrink-0" />
              <span className="sidebar-item-label text-truncate">
                <FormattedMessage
                  id="components.layout.sidebar.sidebar-footer.SidebarFooter.infoLabel"
                  defaultMessage="About"
                />
              </span>
            </Button>
          </OverlayTrigger>
        </div>

        <div className="sidebar-footer-divider" />

        <div className="sidebar-footer-action-item sidebar-footer-action">
          <div className="sidebar-logout">
            <SidebarItem
              label={
                <FormattedMessage
                  id="components.layout.sidebar.sidebar-footer.SidebarFooter.logoutLabel"
                  defaultMessage="Logout"
                />
              }
              icon="logout"
              route={Route.logout}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

export type { SidebarFooterProps };

export default SidebarFooter;
