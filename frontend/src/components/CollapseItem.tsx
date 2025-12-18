/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import { useState } from "react";
import { useIntl } from "react-intl";
import { Card, Button, Collapse } from "react-bootstrap";

import Icon from "@/components/Icon";
import ContainerStatus, {
  parseContainerState,
} from "@/components/ContainerStatus";

export function useCollapseToggle(defaultOpen = false) {
  const [open, setOpen] = useState(defaultOpen);
  const toggle = () => setOpen((prev) => !prev);
  return { open, toggle };
}

export function useCollapsibleSections<T extends string | number>(
  defaultOpenSections: T[] = [],
) {
  const [openSections, setOpenSections] = useState<T[]>(defaultOpenSections);

  const toggleSection = (section: T) => {
    setOpenSections((current) =>
      current.includes(section)
        ? current.filter((s) => s !== section)
        : [...current, section],
    );
  };

  const isSectionOpen = (section: T) => openSections.includes(section);
  return { openSections, toggleSection, isSectionOpen, setOpenSections };
}

interface CollapseCaretProps {
  open: boolean;
}

const CollapseCaret = ({ open }: CollapseCaretProps) => {
  return (
    <span
      style={{
        display: "inline-flex",
        transition: "transform 0.2s ease-in-out",
        transform: open ? "rotate(0deg)" : "rotate(-180deg)",
      }}
    >
      <Icon icon="caretDown" />
    </span>
  );
};

interface CollapseHeaderButtonProps {
  open: boolean;
  onToggle: () => void;
  children: React.ReactNode;
  className?: string;
  style?: React.CSSProperties;
  title?: string;
}

const CollapseHeaderButton = ({
  open,
  onToggle,
  children,
  className,
  style,
  title,
}: CollapseHeaderButtonProps) => (
  <Button
    variant="light"
    className={className}
    style={style}
    onClick={onToggle}
    aria-expanded={open}
    title={title}
  >
    {children}
  </Button>
);

type CollapseType = "flat" | "card-parent" | "card-child";

interface CollapseItemProps {
  title: React.ReactNode;
  children: React.ReactNode;
  open: boolean;
  onToggle: () => void;
  containerStatus?: string | null;
  isInsideTable?: boolean;
  type?: CollapseType;
}

const CollapseItem = ({
  title,
  children,
  open,
  onToggle,
  containerStatus,
  isInsideTable = false,
  type = "card-child",
}: CollapseItemProps) => {
  const intl = useIntl();

  const isFlat = type === "flat";
  const isParent = type === "card-parent";

  if (isFlat) {
    const collapseTitle = isInsideTable
      ? open
        ? intl.formatMessage({
            id: "components.CollapseItem.collapseList",
            defaultMessage: "Collapse list",
          })
        : intl.formatMessage({
            id: "components.CollapseItem.expandList",
            defaultMessage: "Expand list",
          })
      : undefined;

    return (
      <div
        className={
          !isInsideTable ? `mb-2 border-bottom ${open ? "pb-4" : "pb-1"}` : ""
        }
      >
        <CollapseHeaderButton
          open={open}
          onToggle={onToggle}
          title={collapseTitle}
          className={`w-100 d-flex align-items-center ps-0 pe-1 ${!isInsideTable ? "fw-bold" : ""}`}
          style={{ backgroundColor: "transparent", border: "none" }}
        >
          <span className="d-flex align-items-center gap-2">
            {title}
            <CollapseCaret open={open} />
          </span>
        </CollapseHeaderButton>

        <Collapse in={open}>
          <div className={isInsideTable ? "" : "pt-3"}>{children}</div>
        </Collapse>
      </div>
    );
  }

  return (
    <Card className={`shadow-sm ${isParent ? "mb-3" : "mb-2"}`}>
      <Card.Header className="p-0">
        <CollapseHeaderButton
          open={open}
          onToggle={onToggle}
          className={`w-100 d-flex align-items-center ${isParent ? "fw-bold p-2" : "fw-semibold p-1"}`}
          style={{ fontSize: isParent ? "1rem" : "0.9rem" }}
        >
          <span>{title}</span>

          <span className="ms-auto d-inline-flex gap-2 align-items-center">
            {containerStatus && (
              <ContainerStatus state={parseContainerState(containerStatus)} />
            )}
            <CollapseCaret open={open} />
          </span>
        </CollapseHeaderButton>
      </Card.Header>

      <Collapse in={open}>
        <div className={`border-top ${isParent ? "p-3" : "p-2"}`}>
          {children}
        </div>
      </Collapse>
    </Card>
  );
};

export default CollapseItem;
