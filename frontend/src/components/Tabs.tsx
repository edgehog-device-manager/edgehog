// This file is part of Edgehog.
//
// Copyright 2021-2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import Button from "@/components/Button";
import SegmentedControl from "@/components/SegmentedControl";
import "@/components/Tabs.scss";

type EventKey = string;

type TabRef = {
  eventKey: EventKey;
  title?: React.ReactNode;
};

type TabsContextValue = {
  activeKey: EventKey | undefined;
  registerTab: (tabRef: TabRef) => void;
  unregisterTab: (eventKey: EventKey) => void;
};

const TabsContext = createContext<TabsContextValue>({
  activeKey: undefined,
  registerTab: () => {},
  unregisterTab: () => {},
});

type TabButtonProps = {
  isActive: boolean;
  tabRef: TabRef;
};

const TabButton = ({ isActive, tabRef }: TabButtonProps) => {
  const dynamicClasses = isActive
    ? "px-4 py-3 fw-bold active"
    : "px-4 py-2 text-muted";

  return (
    <Button variant="text" className={`tab-button border-0 ${dynamicClasses}`}>
      {tabRef.title}
    </Button>
  );
};

type TabsProps = {
  children?: React.ReactNode;
  className?: string;
  defaultActiveKey?: EventKey;
  tabsOrder?: EventKey[];
  onChange?: (tabKey: string) => void;
};

const Tabs = ({
  children,
  className,
  defaultActiveKey,
  tabsOrder = [],
  onChange = () => {},
}: TabsProps) => {
  const [selectedKey, setSelectedKey] = useState<EventKey | undefined>(
    defaultActiveKey,
  );
  const [tabRefs, setTabRefs] = useState<TabRef[]>([]);

  const registerTab = useCallback((tabRef: TabRef) => {
    setTabRefs((prev) => {
      if (prev.some((ref) => ref.eventKey === tabRef.eventKey)) return prev;
      return [...prev, tabRef];
    });
  }, []);

  const unregisterTab = useCallback((eventKey: EventKey) => {
    setTabRefs((prev) => prev.filter((tabRef) => tabRef.eventKey !== eventKey));
  }, []);

  const activeKey = useMemo(
    () =>
      tabRefs.some((tabRef) => tabRef.eventKey === selectedKey)
        ? selectedKey
        : tabRefs[0]?.eventKey,
    [tabRefs, selectedKey],
  );

  const contextValue = useMemo(
    () => ({
      activeKey,
      registerTab,
      unregisterTab,
    }),
    [activeKey, registerTab, unregisterTab],
  );

  const sortedTabRefs = useMemo(() => {
    const refMap = new Map(tabRefs.map((ref) => [ref.eventKey, ref]));

    const orderedKeys = tabsOrder.filter((key) => refMap.has(key));

    const remainingKeys = tabRefs
      .map((ref) => ref.eventKey)
      .filter((key) => !tabsOrder.includes(key));

    return [...orderedKeys, ...remainingKeys].map((key) => refMap.get(key)!);
  }, [tabRefs, tabsOrder]);

  const handleOnChange = useCallback(
    (key: string) => {
      setSelectedKey(key);
      onChange(key);
    },
    [onChange],
  );

  return (
    <TabsContext.Provider value={contextValue}>
      <div className={className}>
        {sortedTabRefs.length > 0 && (
          <SegmentedControl
            activeId={activeKey}
            items={sortedTabRefs}
            getItemId={(tabRef) => tabRef.eventKey}
            onChange={handleOnChange}
            showControls
          >
            {(tabRef, isActive) => (
              <TabButton tabRef={tabRef} isActive={isActive} />
            )}
          </SegmentedControl>
        )}
        {children}
      </div>
    </TabsContext.Provider>
  );
};

const useTabs = (): TabsContextValue => {
  const tabsContextValue = useContext(TabsContext);
  if (!tabsContextValue) {
    throw new Error("useTabs must be used within a <Tabs /> provider");
  }
  return tabsContextValue;
};

type TabProps = React.ComponentPropsWithoutRef<"div"> & {
  eventKey: EventKey;
  title?: React.ReactNode;
};

const Tab = ({ eventKey, title, ...restProps }: TabProps) => {
  const { registerTab, unregisterTab, activeKey } = useTabs();

  useEffect(() => {
    registerTab({ eventKey, title });
    return () => unregisterTab(eventKey);
  }, [registerTab, unregisterTab, eventKey, title]);

  if (activeKey !== eventKey) {
    return null;
  }

  return <div {...restProps} />;
};

export { Tab };

export default Tabs;
