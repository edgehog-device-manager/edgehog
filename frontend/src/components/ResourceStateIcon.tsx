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

import Icon from "@/components/Icon";

const AVAILABLE_STATES = new Set(["available", "pulled", "present"]);

type ResourceStateIconProps = {
  state: string | null | undefined;
  isReady: boolean | null | undefined;
};

const ResourceStateIcon = ({ state, isReady }: ResourceStateIconProps) => {
  if (!isReady) {
    return (
      <Icon
        icon="spinner"
        className="text-muted fa-spin"
        aria-label="Pending"
      />
    );
  }

  const normalizedState = state?.toLowerCase();

  if (normalizedState && AVAILABLE_STATES.has(normalizedState)) {
    return (
      <Icon
        icon="circleCheck"
        className="text-success"
        aria-label="Available"
      />
    );
  }

  return (
    <Icon
      icon="circleEmpty"
      className="text-secondary"
      aria-label="Unavailable"
    />
  );
};

export default ResourceStateIcon;
