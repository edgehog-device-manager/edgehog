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

import MonacoEditor from "components/MonacoEditor";
import { useCallback } from "react";

type MonacoJsonEditorProps = {
  value: string;
  onChange?: (value: string | undefined) => void;
  defaultValue?: string;
  readonly?: boolean;
  initialLines?: number;
  autoFormat?: boolean;
  /**
   * @important The function is assumed to throw an Error if it fails to parse the
   * text entered in the editor is correctly parsed.
   * The Thrown error will be visualised by the editor as aid for the user.
   * @important input text is already validated to be parsed JSON, so there is
   * no need to validate it again. It can be safely used with this assumption.
   * @returns only if it correctly parses */
  additionalValidation?: (text: any) => void;
};

const MonacoJsonEditor = ({
  value,
  onChange,
  defaultValue,
  readonly = false,
  initialLines = 5,
  autoFormat = true,
  additionalValidation: additionalValidationProp,
}: MonacoJsonEditorProps) => {
  const validationFunction = useCallback(
    (text: any) => {
      const json_text = JSON.parse(text);
      if (additionalValidationProp) {
        additionalValidationProp(json_text);
      }
    },
    [additionalValidationProp],
  );

  return (
    <MonacoEditor
      language={"json"}
      value={value}
      onChange={onChange}
      defaultValue={defaultValue}
      readonly={readonly}
      initialLines={initialLines}
      autoFormat={autoFormat}
      validationFunction={validationFunction}
      languageForErrorString={"JSON"}
    />
  );
};

export default MonacoJsonEditor;
