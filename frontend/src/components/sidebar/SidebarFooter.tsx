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

import { FormattedMessage } from "react-intl";

import { Route } from "@/Navigation";
import SidebarItem from "@/components/sidebar/SidebarItem";
import Icon from "@/components/Icon";

type SidebarFooterProps = {
  appName?: string;
  appVersion: string;
  repoUrl?: string;
  docsUrl?: string;
};

const SidebarFooter = ({
  appName,
  appVersion,
  repoUrl,
  docsUrl,
}: SidebarFooterProps) => {
  return (
    <div className="sidebar-footer d-flex flex-column align-items-center flex-shrink-0 mb-2 bg-white border-top">
      <div className="sidebar-logout-wrapper w-100 d-flex mt-2">
        <SidebarItem
          label={
            <FormattedMessage
              id="components.sidebar.SidebarFooter.logoutLabel"
              defaultMessage="Logout"
            />
          }
          icon="logout"
          route={Route.logout}
          className="w-100 justify-content-center"
        />
      </div>
      <div className="sidebar-meta text-muted fw-semibold text-center">
        <div>
          <span className="sidebar-app-name">{appName}</span>
          <small className="text-secondary opacity-75 ms-1">
            v{appVersion}
          </small>
        </div>

        {(repoUrl || docsUrl) && (
          <div className="sidebar-app-name mt-1">
            {repoUrl && (
              <a
                href={repoUrl}
                className="text-reset mx-1"
                target="_blank"
                rel="noreferrer"
              >
                <Icon className="text-black" icon="github" />
              </a>
            )}

            {docsUrl && (
              <a
                href={docsUrl}
                className="text-reset mx-1"
                target="_blank"
                rel="noreferrer"
              >
                <Icon className="text-black" icon="documentation" />
              </a>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export type { SidebarFooterProps };

export default SidebarFooter;
