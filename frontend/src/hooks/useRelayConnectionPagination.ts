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

import _ from "lodash";
import { useCallback, useEffect, useRef } from "react";

import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

type RefetchOptions = {
  fetchPolicy?:
    | "network-only"
    | "store-and-network"
    | "store-or-network"
    | "store-only";
};

type UseRelayConnectionPaginationOptions<TFilter> = {
  hasNext?: boolean;
  isLoadingNext?: boolean;
  loadNext?: (recordsToLoad: number) => void;
  refetch?: (
    variables: {
      first?: number;
      filter?: TFilter;
    },
    options?: RefetchOptions,
  ) => void;
  searchText?: string | null;
  buildFilter?: (searchText: string) => TFilter | undefined;
  recordsToLoadFirst?: number;
  recordsToLoadNext?: number;
  debounceMs?: number;
  refetchPolicy?: RefetchOptions["fetchPolicy"];
};

type UseRelayConnectionPaginationReturn = {
  loadNextPage: () => void;
  onLoadMore: (() => void) | undefined;
};

const useRelayConnectionPagination = <TFilter>({
  hasNext = false,
  isLoadingNext = false,
  loadNext,
  refetch,
  searchText = null,
  buildFilter,
  recordsToLoadFirst = RECORDS_TO_LOAD_FIRST,
  recordsToLoadNext = RECORDS_TO_LOAD_NEXT,
  debounceMs = 500,
  refetchPolicy = "network-only",
}: UseRelayConnectionPaginationOptions<TFilter>): UseRelayConnectionPaginationReturn => {
  const buildFilterRef = useRef(buildFilter);
  const refetchRef = useRef(refetch);
  const recordsToLoadFirstRef = useRef(recordsToLoadFirst);
  const refetchPolicyRef = useRef(refetchPolicy);

  const debouncedRefetchRef = useRef<ReturnType<typeof _.debounce> | null>(
    null,
  );

  useEffect(() => {
    buildFilterRef.current = buildFilter;
  }, [buildFilter]);

  useEffect(() => {
    refetchRef.current = refetch;
  }, [refetch]);

  useEffect(() => {
    recordsToLoadFirstRef.current = recordsToLoadFirst;
  }, [recordsToLoadFirst]);

  useEffect(() => {
    refetchPolicyRef.current = refetchPolicy;
  }, [refetchPolicy]);

  useEffect(() => {
    const debouncedFn = _.debounce((text: string) => {
      const currentRefetch = refetchRef.current;

      if (!currentRefetch) {
        return;
      }

      const filter = buildFilterRef.current?.(text);

      if (filter === undefined) {
        currentRefetch(
          {
            first: recordsToLoadFirstRef.current,
          },
          { fetchPolicy: refetchPolicyRef.current },
        );

        return;
      }

      currentRefetch(
        {
          first: recordsToLoadFirstRef.current,
          filter,
        },
        { fetchPolicy: refetchPolicyRef.current },
      );
    }, debounceMs);

    debouncedRefetchRef.current = debouncedFn;

    return () => {
      debouncedFn.cancel();
    };
  }, [debounceMs]);

  useEffect(() => {
    if (searchText == null) {
      return;
    }

    debouncedRefetchRef.current?.(searchText);
  }, [searchText]);

  const loadNextPage = useCallback(() => {
    if (loadNext && hasNext && !isLoadingNext) {
      loadNext(recordsToLoadNext);
    }
  }, [hasNext, isLoadingNext, loadNext, recordsToLoadNext]);

  return {
    loadNextPage,
    onLoadMore: loadNext && hasNext ? loadNextPage : undefined,
  };
};

export default useRelayConnectionPagination;
