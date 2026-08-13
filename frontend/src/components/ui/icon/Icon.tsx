/*
  This file is part of Edgehog.

  Copyright 2021-2026 SECO Mind Srl

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

import {
  Menu,
  Cpu,
  ArrowDown,
  ArrowUp,
  ArrowRight,
  ChevronsLeft,
  ChevronsRight,
  ChevronDown,
  ChevronUp,
  SquareArrowOutUpRight,
  ScrollText,
  Circle,
  Calendar,
  CircleCheck,
  CircleDashed,
  CircleQuestionMark,
  Trash,
  FolderOpen,
  CodeXml,
  Sailboat,
  Save,
  Pause,
  Play,
  Plus,
  Puzzle,
  User,
  Search,
  LoaderPinwheel,
  Square,
  Pencil,
  X,
  Eye,
  EyeOff,
  CircleAlert,
  Info,
  LogOut,
  RotateCcw,
  CircleFadingArrowUp,
  CloudUpload,
  Container,
  Earth,
  GlobeOff,
  Gpu,
  TabletSmartphone,
  Group,
  Antenna,
  Folders,
  RadioTower,
  Library,
  KeyRound,
  HardDrive,
  Network,
  Package,
  HardDriveDownload,
  Grid2x2Check,
  EllipsisVertical,
  type LucideProps,
} from "lucide-react";

const icons = {
  arrowDown: ArrowDown,
  arrowUp: ArrowUp,
  arrowRight: ArrowRight,
  anglesLeft: ChevronsLeft,
  anglesRight: ChevronsRight,
  arrowUpRightFromSquare: SquareArrowOutUpRight,
  documentation: ScrollText,
  caretDown: ChevronDown,
  caretUp: ChevronUp,
  circle: Circle,
  calendar: Calendar,
  check: CircleCheck,
  empty: CircleDashed,
  delete: Trash,
  devices: Cpu,
  deviceOnline: Earth,
  deviceOffline: GlobeOff,
  folder: FolderOpen,
  github: CodeXml,
  fleet: Sailboat,
  models: Puzzle,
  os: Save,
  pause: Pause,
  play: Play,
  plus: Plus,
  profile: User,
  search: Search,
  spinner: LoaderPinwheel,
  stop: Square,
  edit: Pencil,
  xMark: X,
  showPassword: Eye,
  hidePassword: EyeOff,
  warning: CircleAlert,
  info: Info,
  logout: LogOut,
  menu: Menu,
  rotate: RotateCcw,
  upgrade: CircleFadingArrowUp,
  otaUpdates: CloudUpload,
  applications: Package,
  question: CircleQuestionMark,
  hardwareTypes: Gpu,
  systemModels: TabletSmartphone,
  deviceGroups: Group,
  channels: Antenna,
  repositories: Folders,
  campaign: RadioTower,
  baseImageCollections: Library,
  imageCredentials: KeyRound,
  volumes: HardDrive,
  networks: Network,
  containers: Container,
  deployments: HardDriveDownload,
  columnVisibility: Grid2x2Check,
  details: EllipsisVertical,
} as const;

export type IconName = keyof typeof icons;

interface Props extends LucideProps {
  icon: IconName;
}

const Icon = ({ icon, className, ...restProps }: Props) => {
  const IconComponent = icons[icon];

  return (
    <IconComponent
      className={className}
      size="1.2em"
      {...restProps}
      role="icon"
    />
  );
};

export default Icon;
