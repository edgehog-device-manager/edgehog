// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
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

import { memo } from "react";

type ResourceStateVariant = "ready" | "not-ready" | "error";

const VARIANT_CLASS: Record<ResourceStateVariant, string> = {
  ready: "text-success",
  "not-ready": "text-body-tertiary",
  error: "text-danger",
};

type ResourceStateProps = {
  state: string | null | undefined;
  isReady?: boolean | null;
};

const resolveVariant = (
  state: string | null | undefined,
  isReady: boolean | null | undefined,
): { variant: ResourceStateVariant; display: string } | null => {
  if (state == null) {
    // Should not happen, but treat explicit readiness as ready
    if (isReady === true) {
      return { variant: "ready", display: "READY" };
    }
    return null;
  }
  if (state.toUpperCase() === "ERROR") {
    return { variant: "error", display: state };
  }
  return isReady === true
    ? { variant: "ready", display: state }
    : { variant: "not-ready", display: state };
};

const ResourceState = ({ state, isReady }: ResourceStateProps) => {
  const resolved = resolveVariant(state, isReady);
  if (!resolved) return null;

  const { variant, display } = resolved;

  return (
    <span
      className={`font-monospace fw-bold text-uppercase text-truncate small flex-shrink-0 ms-auto ${VARIANT_CLASS[variant]}`}
      title={display}
      translate="no"
    >
      {display}
    </span>
  );
};

export default memo(ResourceState);
