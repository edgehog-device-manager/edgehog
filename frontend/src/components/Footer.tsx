/*
 * This file is part of Edgehog.
 *
 * Copyright 2022-2026 SECO Mind Srl
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

import { useIntl } from "react-intl";

import assets from "@/assets";
import Center from "@/components/Center";
import Icon from "@/components/Icon";
import Stack from "@/components/Stack";
import "./Footer.scss";

type FooterProps = {
  appName: string;
  appVersion: string;
  homepageUrl: string;
  repoUrl: string;
  issueTrackerUrl: string;
};

const Footer = ({
  appName,
  appVersion,
  homepageUrl,
  repoUrl,
  issueTrackerUrl,
}: FooterProps) => {
  const intl = useIntl();
  return (
    <footer className="py-2 border-top">
      <Center>
        <div>
          <Stack gap={2} direction="horizontal">
            <a
              href={homepageUrl}
              aria-label={intl.formatMessage({
                id: "components.Footer.edgehogHomeLinkLabel",
                defaultMessage: "Edgehog Homepage Link",
              })}
            >
              <img
                alt={intl.formatMessage({
                  id: "components.Footer.logo",
                  defaultMessage: "Logo",
                })}
                className="py-1"
                src={assets.images.logo}
              />
            </a>
            <span>
              {appName} <small>(v{appVersion})</small>
            </span>
            <a
              href={repoUrl}
              className="text-reset"
              target="_blank"
              rel="noreferrer"
              aria-label={intl.formatMessage({
                id: "components.Footer.repositoryLinkLabel",
                defaultMessage: "GitHub",
              })}
            >
              <Icon icon="github" />
            </a>
            <a
              href={issueTrackerUrl}
              className="text-reset"
              target="_blank"
              rel="noreferrer"
              aria-label={intl.formatMessage({
                id: "components.Footer.issuesLinkLabel",
                defaultMessage: "GitHub-Issues",
              })}
            >
              <Icon icon="bug" />
            </a>
          </Stack>
        </div>
      </Center>
    </footer>
  );
};

export default Footer;
