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

import React, { useEffect, useRef } from "react";
import Nav from "react-bootstrap/Nav";

import Button from "@/components/Button";
import Icon from "@/components/Icon";
import Stack, { StackProps } from "@/components/Stack";

const SegmentedControlStack = React.forwardRef((props: StackProps, ref) => (
  <Stack ref={ref} as="ul" {...props} />
));

type Props<Item, ItemId = Item> = {
  activeId?: ItemId;
  children: (item: Item, isActive: boolean) => React.ReactNode;
  className?: string;
  getItemId?: (item: Item) => ItemId;
  items: Item[];
  onChange?: (itemId: ItemId) => void;
  showControls?: boolean;
};

const DEFAULT_GET_ITEM_ID = <Item, ItemId>(item: Item) =>
  item as unknown as ItemId;

function SegmentedControl<Item, ItemId = Item>({
  activeId,
  children,
  className = "",
  getItemId = DEFAULT_GET_ITEM_ID,
  items,
  onChange = () => {},
  showControls = false,
}: Props<Item, ItemId>) {
  const itemsRef = useRef<HTMLUListElement>(null);

  const totalItems = items.length;
  const activeItemIndex = items.findIndex(
    (item) => getItemId(item) === activeId,
  );

  const prevItemIndex =
    totalItems > 0 ? (activeItemIndex - 1 + totalItems) % totalItems : 0;
  const nextItemIndex = totalItems > 0 ? (activeItemIndex + 1) % totalItems : 0;

  const canNavigate = totalItems > 1 && activeItemIndex !== -1;

  useEffect(() => {
    const itemsNode = itemsRef.current;
    if (!itemsNode) return;

    const handleWheel = (e: WheelEvent) => {
      if (e.deltaY !== 0) {
        e.preventDefault();
        itemsNode.scrollLeft += e.deltaY;
      }
    };

    itemsNode.addEventListener("wheel", handleWheel, { passive: false });

    return () => {
      itemsNode.removeEventListener("wheel", handleWheel);
    };
  }, []);

  useEffect(() => {
    if (activeItemIndex === -1) return;

    const itemsNode = itemsRef.current;
    const itemNode = itemsNode?.querySelector<HTMLLIElement>(
      `li[data-index="${activeItemIndex}"]`,
    );

    if (itemsNode && itemNode) {
      const itemWidth = itemNode.offsetWidth;
      const offsetToItemLeft = itemNode.offsetLeft - itemsNode.offsetLeft;
      const offsetToItemCenter = offsetToItemLeft + itemWidth / 2;
      const containerVisibleWidth = itemsNode.clientWidth;

      itemsNode.scrollTo({
        left: offsetToItemCenter - containerVisibleWidth / 2,
        behavior: "smooth",
      });
    }
  }, [activeItemIndex]);

  const handleChangeItem = (index: number) => {
    const item = items[index];
    if (item) {
      onChange(getItemId(item));
    }
  };

  return (
    <div
      className={`border-0 overflow-auto hstack gap-2 custom-scrollbar ${className}`}
    >
      {showControls && (
        <Button
          variant="text"
          className="border-0"
          disabled={!canNavigate}
          onClick={() => handleChangeItem(prevItemIndex)}
        >
          <Icon icon="anglesLeft" />
        </Button>
      )}
      <Nav
        ref={itemsRef}
        role="tablist"
        variant="pills"
        className="nav-tabs border-0 flex-grow-1 flex-nowrap overflow-auto custom-scrollbar"
        as={SegmentedControlStack}
        direction="horizontal"
        gap={2}
      >
        {items.map((item, index) => {
          const itemId = getItemId(item);
          const isActive = itemId === activeId;

          const itemKey =
            getItemId === DEFAULT_GET_ITEM_ID && typeof item === "object"
              ? index
              : String(itemId);

          return (
            <Nav.Item
              key={itemKey}
              as="li"
              data-index={index}
              role="presentation"
              className="flex-shrink-0"
              onClick={(event: React.MouseEvent) => {
                if (event.preventDefault) event.preventDefault();
                handleChangeItem(index);
              }}
            >
              {children(item, isActive)}
            </Nav.Item>
          );
        })}
      </Nav>
      {showControls && (
        <Button
          variant="text"
          className="text-muted border-0"
          disabled={!canNavigate}
          onClick={() => handleChangeItem(nextItemIndex)}
        >
          <Icon icon="anglesRight" />
        </Button>
      )}
    </div>
  );
}

export default SegmentedControl;
