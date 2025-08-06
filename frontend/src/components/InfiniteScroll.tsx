/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { useEffect, useRef } from "react";

import Spinner from "components/Spinner";

// Set flex: 1 for the container together with a fixed flex-basis.
// This will ensure the container will fill the available height of its parent
// but also trigger an overflow condition if it spans more height.
// The overflow can then be handled with an overflow: auto to hide excess
// content and display the scroll bar.
// For more details see: https://stackoverflow.com/a/52489012
const containerStyle = { flex: "1 1 1px" };

type Props = {
  children?: React.ReactNode;
  className?: string;
  loading?: boolean;
  onLoadMore?: () => void;
};

const InfiniteScroll = ({
  children,
  className,
  loading = false,
  onLoadMore,
}: Props) => {
  const sentinelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!onLoadMore || !sentinel || !window.IntersectionObserver) {
      return;
    }
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        onLoadMore();
      }
    });
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [sentinelRef, onLoadMore]);

  return (
    <div className={`flex-grow-1 d-flex flex-column ${className}`}>
      <div className="overflow-visible overflow-xl-auto" style={containerStyle}>
        {children}
        {(loading || onLoadMore) && (
          <div className="text-center mt-3" ref={sentinelRef}>
            <Spinner />
          </div>
        )}
      </div>
    </div>
  );
};

export default InfiniteScroll;
