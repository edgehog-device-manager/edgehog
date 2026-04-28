/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
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

import { useCallback, useRef, useState } from "react";
import { useIntl } from "react-intl";
import { Button, Collapse } from "react-bootstrap";

import Icon from "@/components/Icon";

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

const CollapseCaret = ({ open }: { open: boolean }) => (
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

type CollapseHeaderButtonProps = {
  open: boolean;
  onToggle: () => void;
  children: React.ReactNode;
  className?: string;
  style?: React.CSSProperties;
  title?: string;
};

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
type CollapseItemProps = {
  title: React.ReactNode;
  children: React.ReactNode;
  rightContent?: React.ReactNode;
  caretPosition?: "left" | "right" | "end";
  open: boolean;
  onToggle: () => void;
  showToggleTooltip?: boolean;
  style?: React.CSSProperties;
  className?: string;
  headerClassName?: string;
  contentClassName?: string;
};

const CollapseItem = ({
  title,
  children,
  rightContent,
  caretPosition,
  open,
  onToggle,
  showToggleTooltip = false,
  style,
  className,
  headerClassName,
  contentClassName,
}: CollapseItemProps) => {
  const intl = useIntl();
  const containerRef = useRef<HTMLDivElement | null>(null);

  const handleScrollIntoView = useCallback(() => {
    if (!containerRef.current) return;

    const rect = containerRef.current.getBoundingClientRect();
    if (rect.bottom > window.innerHeight) {
      containerRef.current.scrollIntoView({
        behavior: "smooth",
        block: "nearest",
      });
    }
  }, []);

  const collapseTitle = showToggleTooltip
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

  const renderCaret = () => <CollapseCaret open={open} />;

  return (
    <div ref={containerRef} className={className}>
      <CollapseHeaderButton
        open={open}
        onToggle={onToggle}
        title={collapseTitle}
        className={`d-flex align-items-center w-100 ${headerClassName ?? ""}`}
        style={style}
      >
        <div className="d-flex align-items-center gap-2">
          {caretPosition === "left" && renderCaret()}
          <span>{title}</span>
          {caretPosition === "right" && renderCaret()}
        </div>

        {(rightContent || caretPosition === "end") && (
          <div className="ms-auto d-flex align-items-center gap-2">
            {caretPosition === "end" && renderCaret()}
            {rightContent}
          </div>
        )}
      </CollapseHeaderButton>

      <Collapse in={open} onEntered={handleScrollIntoView}>
        <div className={contentClassName}>{children}</div>
      </Collapse>
    </div>
  );
};

export default CollapseItem;
