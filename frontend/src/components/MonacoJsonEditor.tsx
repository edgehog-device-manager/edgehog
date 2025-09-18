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

import { useRef, useState, useCallback } from "react";
import { Editor } from "@monaco-editor/react";
import { FormattedMessage } from "react-intl";

import Icon from "components/Icon";

type MonacoJsonEditorProps = {
  value: string;
  language?: string;
  onChange?: (value: string | undefined) => void;
  defaultValue?: string;
  readonly?: boolean;
  initialLines?: number;
  autoFormat?: boolean;
};

const MonacoJsonEditor = ({
  value,
  language = "json",
  onChange,
  defaultValue,
  readonly = false,
  initialLines = 5,
  autoFormat = true,
}: MonacoJsonEditorProps) => {
  const editorRef = useRef<any>(null);
  const lineHeight = 22;
  const [height, setHeight] = useState(initialLines * lineHeight);
  const [jsonError, setJsonError] = useState<string | null>(null);

  const formatJson = useCallback(() => {
    if (editorRef.current && autoFormat && language === "json") {
      try {
        const currentValue = editorRef.current.getValue();
        JSON.parse(currentValue); // validacija
        editorRef.current.getAction("editor.action.formatDocument").run();
        setJsonError(null); // nema greške
      } catch (error: any) {
        setJsonError(error.message); // snimi grešku
      }
    }
  }, [autoFormat, language]);

  const updateHeight = useCallback(() => {
    if (editorRef.current) {
      const contentHeight = editorRef.current.getContentHeight();
      const minHeight = initialLines * lineHeight;
      setHeight(Math.max(contentHeight, minHeight));
      editorRef.current.layout();
    }
  }, [initialLines]);

  const handleEditorDidMount = (editor: any) => {
    editorRef.current = editor;
    editor.onDidContentSizeChange(updateHeight);
    editor.onDidChangeModelContent(() => {
      setTimeout(formatJson, 100);
    });
    updateHeight();
  };

  return (
    <div className="border rounded bg-white p-2 overflow-hidden">
      <Editor
        height={height}
        defaultLanguage={language}
        value={value}
        onChange={onChange}
        defaultValue={defaultValue}
        onMount={handleEditorDidMount}
        options={{
          automaticLayout: true,
          minimap: { enabled: false },
          scrollBeyondLastLine: false,
          wordWrap: "on",
          readOnly: readonly,
          lineNumbers: "off",
          scrollbar: {
            vertical: "hidden",
            horizontal: "hidden",
            alwaysConsumeMouseWheel: false,
          },
        }}
      />
      {jsonError && (
        <p className="text-red-500 text-sm mt-2">
          <Icon icon="warning" />
          <FormattedMessage
            id="components.MonacoJsonEditor.jsonError"
            defaultMessage="JSON error: {error}"
            values={{ error: jsonError }}
          />
        </p>
      )}
    </div>
  );
};

export default MonacoJsonEditor;
