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

import { FormattedMessage, useIntl } from "react-intl";

import Select from "@/components/ui/select/Select";

export type EnvStrategy = "merge" | "override";

type Props = {
  value: EnvStrategy;
  onChange: (v: EnvStrategy) => void;
};

const options: { value: EnvStrategy; label: string }[] = [
  { value: "merge", label: "Merge" },
  { value: "override", label: "Override" },
];

const EnvStrategySelect = ({ value, onChange }: Props) => {
  const intl = useIntl();
  const selected = options.find((o) => o.value === value) || options[0];
  return (
    <div>
      <Select
        value={selected}
        onChange={(opt) => {
          if (opt) onChange(opt.value as EnvStrategy);
        }}
        options={options}
        isClearable={false}
        menuPortalTarget={document.body}
        menuPosition="fixed"
        styles={{
          menuPortal: (base: any) => ({ ...base, zIndex: 9999 }) as any,
        }}
        aria-label={intl.formatMessage({
          id: "components.deploy.EnvStrategySelect.label",
          defaultMessage: "Env strategy",
        })}
      />
      <div className="form-text small text-muted">
        {value === "merge" ? (
          <FormattedMessage
            id="components.deploy.EnvStrategySelect.mergeHint"
            defaultMessage="Merge keeps container defaults; your keys win on duplicates."
          />
        ) : (
          <FormattedMessage
            id="components.deploy.EnvStrategySelect.overrideHint"
            defaultMessage="Override replaces all container defaults with your values."
          />
        )}
      </div>
    </div>
  );
};

export default EnvStrategySelect;
