/*
  This file is part of Edgehog.

  Copyright 2021-2025 SECO Mind Srl

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

import { faGithub } from "@fortawesome/free-brands-svg-icons";
import {
  faAngleDown,
  faAngleUp,
  faArrowAltCircleUp,
  faArrowDown,
  faArrowUp,
  faArrowRight,
  faBug,
  faCheck,
  faCircle,
  faCloud,
  faCompactDisc,
  faDatabase,
  faPlay,
  faPlus,
  faRocket,
  faSearch,
  faSpinner,
  faStop,
  faSwatchbook,
  faTabletAlt,
  faTimes,
  faTrash,
  faUser,
  faEye,
  faEyeSlash,
  faTriangleExclamation,
  faObjectGroup,
  faCircleQuestion,
  faRotate,
  faCircleInfo,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";

const icons = {
  arrowDown: faArrowDown,
  arrowUp: faArrowUp,
  arrowRight: faArrowRight,
  bug: faBug,
  caretDown: faAngleDown,
  caretUp: faAngleUp,
  circle: faCircle,
  delete: faTrash,
  devices: faTabletAlt,
  deviceGroups: faDatabase,
  github: faGithub,
  models: faSwatchbook,
  os: faCompactDisc,
  play: faPlay,
  plus: faPlus,
  profile: faUser,
  search: faSearch,
  spinner: faSpinner,
  stop: faStop,
  check: faCheck,
  close: faTimes,
  otaUpdates: faCloud,
  applications: faRocket,
  upgrade: faArrowAltCircleUp,
  showPassword: faEye,
  hidePassword: faEyeSlash,
  warning: faTriangleExclamation,
  channels: faObjectGroup,
  faCircleQuestion: faCircleQuestion,
  rotate: faRotate,
  faCircleInfo: faCircleInfo,
} as const;

type FontAwesomeIconProps = React.ComponentProps<typeof FontAwesomeIcon>;

type Props = Omit<FontAwesomeIconProps, "icon"> & {
  icon: keyof typeof icons;
};

const Icon = ({ icon, ...restProps }: Props) => {
  return <FontAwesomeIcon {...restProps} icon={icons[icon]} />;
};

export default Icon;
