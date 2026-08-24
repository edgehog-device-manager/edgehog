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

import { useCallback, useEffect, useRef, useState } from "react";
import { Editor } from "@monaco-editor/react";
import type * as Monaco from "monaco-editor";
import { initVimMode } from "monaco-vim";
import { useIntl } from "react-intl";
import Button from "react-bootstrap/Button";

import Icon from "@/components/ui/icon/Icon";
import useEditorPreferences, {
  DEFAULT_EDITOR_FONT_SIZE,
} from "@/hooks/useEditorPreferences";

type MonacoEditorProps = {
  value: string;
  language?: string;
  onChange?: (value: string | undefined) => void;
  defaultValue?: string;
  readonly?: boolean;
  initialLines?: number;
  autoFormat?: boolean;
  error?: string;
  fillHeight?: boolean;
};

const FONT_SIZE_STEP = 2;

const MonacoEditor = ({
  value,
  language,
  onChange,
  defaultValue,
  readonly = false,
  initialLines = 5,
  autoFormat = true,
  error,
  fillHeight = false,
}: MonacoEditorProps) => {
  const intl = useIntl();
  const lineHeight = 22;
  const [height, setHeight] = useState(initialLines * lineHeight);

  const editorRef = useRef<Monaco.editor.IStandaloneCodeEditor | null>(null);
  const monacoRef = useRef<typeof Monaco | null>(null);
  const vimAdapterRef = useRef<ReturnType<typeof initVimMode> | null>(null);
  const statusBarRef = useRef<HTMLDivElement | null>(null);

  const [editorReady, setEditorReady] = useState(false);
  const { preferences, updatePreferences } = useEditorPreferences();

  const format = useCallback(() => {
    if (editorRef.current && autoFormat && language) {
      // Only format if it's valid JSON (for json language)
      if (language === "json") {
        try {
          const currentValue = editorRef.current.getValue();
          JSON.parse(currentValue);
          editorRef.current.getAction("editor.action.formatDocument")?.run();
        } catch {
          // Invalid JSON, don't format
        }
      } else {
        editorRef.current.getAction("editor.action.formatDocument")?.run();
      }
    }
  }, [autoFormat, language]);

  const updateHeight = useCallback(() => {
    if (!fillHeight && editorRef.current) {
      const contentHeight = editorRef.current.getContentHeight();
      const minHeight = initialLines * lineHeight;
      setHeight(Math.max(contentHeight, minHeight));
      editorRef.current.layout();
    }
  }, [initialLines, fillHeight]);

  const changeFontSize = useCallback(
    (delta: number) => {
      updatePreferences((previous) => ({
        ...previous,
        fontSize: previous.fontSize + delta,
      }));
    },
    [updatePreferences],
  );

  const resetFontSize = useCallback(() => {
    updatePreferences((previous) => ({
      ...previous,
      fontSize: DEFAULT_EDITOR_FONT_SIZE,
    }));
  }, [updatePreferences]);

  const handleEditorDidMount = (
    editor: Monaco.editor.IStandaloneCodeEditor,
    monaco: typeof Monaco,
  ) => {
    editorRef.current = editor;
    monacoRef.current = monaco;

    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.Equal, () =>
      changeFontSize(FONT_SIZE_STEP),
    );
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.Minus, () =>
      changeFontSize(-FONT_SIZE_STEP),
    );
    editor.addCommand(
      monaco.KeyMod.CtrlCmd | monaco.KeyCode.Digit0,
      resetFontSize,
    );

    editor.onDidContentSizeChange(updateHeight);
    editor.onDidChangeModelContent(() => {
      setTimeout(format, 100);
    });
    updateHeight();
    setEditorReady(true);
  };

  // apply preference-driven font size, unless it was just changed in the
  // editor itself (e.g. with the mouse wheel)
  useEffect(() => {
    const editor = editorRef.current;
    const monaco = monacoRef.current;

    if (!editorReady || !editor || !monaco) {
      return;
    }

    const option = monaco.editor.EditorOption.fontSize;

    if (editor.getOption(option) !== preferences.fontSize) {
      editor.updateOptions({ fontSize: preferences.fontSize });
    }
  }, [editorReady, preferences.fontSize]);

  useEffect(() => {
    const editor = editorRef.current;
    const monaco = monacoRef.current;

    if (!editorReady || !editor || !monaco) {
      return;
    }

    const option = monaco.editor.EditorOption.fontSize;

    const disposable = editor.onDidChangeConfiguration((event) => {
      if (event.hasChanged(option)) {
        const newSize = editor.getOption(option);

        if (newSize !== preferences.fontSize) {
          updatePreferences((previous) => ({
            ...previous,
            fontSize: newSize,
          }));
        }
      }
    });

    return () => disposable.dispose();
  }, [editorReady, preferences.fontSize, updatePreferences]);

  useEffect(() => {
    if (!editorReady) {
      return;
    }

    if (!preferences.vimEnabled) {
      vimAdapterRef.current?.dispose();
      vimAdapterRef.current = null;

      return;
    }

    if (!vimAdapterRef.current && statusBarRef.current) {
      vimAdapterRef.current = initVimMode(
        editorRef.current!,
        statusBarRef.current,
      );
    }

    return () => {
      vimAdapterRef.current?.dispose();
      vimAdapterRef.current = null;
    };
  }, [editorReady, preferences.vimEnabled]);

  useEffect(
    () => () => {
      vimAdapterRef.current?.dispose();
      vimAdapterRef.current = null;
    },
    [],
  );

  const toggleVim = useCallback(() => {
    updatePreferences((previous) => ({
      ...previous,
      vimEnabled: !previous.vimEnabled,
    }));
  }, [updatePreferences]);

  const vimToggleTitle = intl.formatMessage({
    id: "components.ui.monaco-editor.MonacoEditor.vimToggle",
    defaultMessage: "Toggle Vim mode",
  });
  const zoomOutTitle = intl.formatMessage({
    id: "components.ui.monaco-editor.MonacoEditor.zoomOut",
    defaultMessage: "Decrease font size",
  });
  const zoomInTitle = intl.formatMessage({
    id: "components.ui.monaco-editor.MonacoEditor.zoomIn",
    defaultMessage: "Increase font size",
  });
  const zoomResetTitle = intl.formatMessage({
    id: "components.ui.monaco-editor.MonacoEditor.zoomReset",
    defaultMessage: "Reset font size",
  });

  return (
    <div
      className={`border rounded bg-white p-2 overflow-hidden d-flex flex-column ${
        fillHeight ? "h-100" : ""
      }`}
    >
      <div className="d-flex justify-content-end align-items-center gap-1 mb-1">
        <Button
          variant={preferences.vimEnabled ? "primary" : "outline-secondary"}
          className="py-0 px-2 border-0 fw-bold"
          style={{ fontSize: "0.8rem" }}
          onClick={toggleVim}
          aria-pressed={preferences.vimEnabled}
          title={vimToggleTitle}
        >
          Vim
        </Button>
        <Button
          variant="outline-secondary"
          className="py-0 px-2 border-0"
          style={{ fontSize: "0.8rem" }}
          onClick={() => changeFontSize(-FONT_SIZE_STEP)}
          title={zoomOutTitle}
        >
          A−
        </Button>
        <Button
          variant="outline-secondary"
          className="py-0 px-2 border-0"
          style={{ fontSize: "0.8rem" }}
          onClick={() => changeFontSize(FONT_SIZE_STEP)}
          title={zoomInTitle}
        >
          A+
        </Button>
        <Button
          variant="outline-secondary"
          className="py-0 px-2 border-0"
          onClick={resetFontSize}
          title={zoomResetTitle}
        >
          <Icon icon={"rotate"} />
        </Button>
      </div>

      <div className={fillHeight ? "flex-grow-1 overflow-hidden" : ""}>
        <Editor
          height={fillHeight ? "100%" : height}
          defaultLanguage={language}
          value={value}
          onChange={onChange}
          defaultValue={defaultValue}
          onMount={handleEditorDidMount}
          options={{
            fontFamily: "var(--bs-font-monospace, monospace)",
            automaticLayout: fillHeight,
            minimap: { enabled: false },
            scrollBeyondLastLine: false,
            wordWrap: "off",
            readOnly: readonly,
            lineNumbers: "off",
            mouseWheelZoom: true,
            scrollbar: {
              vertical: fillHeight ? "auto" : "hidden",
              horizontal: "hidden",
              alwaysConsumeMouseWheel: false,
            },
            renderLineHighlight: "none",
          }}
        />
      </div>

      {preferences.vimEnabled && (
        <div
          ref={statusBarRef}
          data-testid="vim-status-bar"
          className="border-top mt-1 px-1 text-muted"
          style={{ fontSize: "0.75rem", minHeight: "18px" }}
        />
      )}

      {error && (
        <p className="text-danger mt-2">
          <Icon icon="warning" className="me-2" />
          {intl.formatMessage({ id: error, defaultMessage: error })}
        </p>
      )}
    </div>
  );
};

export default MonacoEditor;
