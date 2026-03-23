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

import { useCallback, useMemo, useRef, useState } from "react";
import { FormattedMessage } from "react-intl";

import CloseButton from "@/components/CloseButton";
import Icon from "@/components/Icon";
import Tag from "@/components/Tag";
import { formatFileSize } from "@/lib/files";

const readFileEntry = (entry: FileSystemFileEntry): Promise<File> =>
  new Promise((resolve, reject) => entry.file(resolve, reject));

const readDirectoryBatch = (
  reader: FileSystemDirectoryReader,
): Promise<FileSystemEntry[]> =>
  new Promise((resolve, reject) => reader.readEntries(resolve, reject));

const readAllDirectoryEntries = async (
  reader: FileSystemDirectoryReader,
): Promise<FileSystemEntry[]> => {
  const all: FileSystemEntry[] = [];
  let batch: FileSystemEntry[];
  do {
    batch = await readDirectoryBatch(reader);
    all.push(...batch);
  } while (batch.length > 0);
  return all;
};

const collectFilesFromEntry = async (
  entry: FileSystemEntry,
  basePath: string,
): Promise<File[]> => {
  if (entry.isFile) {
    const file = await readFileEntry(entry as FileSystemFileEntry);
    const relativePath = basePath ? `${basePath}/${entry.name}` : "";
    if (relativePath) {
      Object.defineProperty(file, "webkitRelativePath", {
        value: relativePath,
        configurable: true,
      });
    }
    return [file];
  }
  if (entry.isDirectory) {
    const reader = (entry as FileSystemDirectoryEntry).createReader();
    const children = await readAllDirectoryEntries(reader);
    const dirPath = basePath ? `${basePath}/${entry.name}` : entry.name;
    const results: File[] = [];
    for (const child of children) {
      results.push(...(await collectFilesFromEntry(child, dirPath)));
    }
    return results;
  }
  return [];
};

const collectFilesFromDrop = async (
  dataTransfer: DataTransfer,
): Promise<File[]> => {
  const files: File[] = [];
  const items = Array.from(dataTransfer.items);
  for (const item of items) {
    const entry = item.webkitGetAsEntry?.();
    if (entry) {
      files.push(...(await collectFilesFromEntry(entry, "")));
    }
  }
  return files;
};

const getFileKey = (file: File): string => file.webkitRelativePath || file.name;

type FileDropzoneProps = {
  files: File[];
  onChange: (files: File[]) => void;
  isInvalid?: boolean;
};

const FileDropzone = ({ files, onChange, isInvalid }: FileDropzoneProps) => {
  const [isDragOver, setIsDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const folderInputRef = useRef<HTMLInputElement>(null);
  const dragCounter = useRef(0);

  const merge = useCallback(
    (newFiles: File[]) => {
      const existingKeys = new Set(files.map(getFileKey));
      const deduplicated = newFiles.filter(
        (f) => !existingKeys.has(getFileKey(f)),
      );
      onChange([...files, ...deduplicated]);
    },
    [files, onChange],
  );

  const removeFile = useCallback(
    (index: number) => {
      onChange(files.filter((_, i) => i !== index));
    },
    [files, onChange],
  );

  const handleFilesChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newFiles = e.target.files ? Array.from(e.target.files) : [];
    merge(newFiles);
    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  const handleFolderChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newFiles = e.target.files ? Array.from(e.target.files) : [];
    merge(newFiles);
    if (folderInputRef.current) folderInputRef.current.value = "";
  };

  const handleDragEnter = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    dragCounter.current += 1;
    if (dragCounter.current === 1) setIsDragOver(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    dragCounter.current -= 1;
    if (dragCounter.current === 0) setIsDragOver(false);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    dragCounter.current = 0;
    setIsDragOver(false);
    const droppedFiles = await collectFilesFromDrop(e.dataTransfer);
    merge(droppedFiles);
  };

  const totalSize = useMemo(
    () => files.reduce((sum, f) => sum + f.size, 0),
    [files],
  );

  return (
    <>
      <input
        ref={fileInputRef}
        type="file"
        multiple
        onChange={handleFilesChange}
        className="d-none"
      />
      <input
        ref={folderInputRef}
        type="file"
        // @ts-expect-error webkitdirectory is non-standard but widely supported
        webkitdirectory=""
        onChange={handleFolderChange}
        className="d-none"
      />
      <div
        onDragEnter={handleDragEnter}
        onDragLeave={handleDragLeave}
        onDragOver={handleDragOver}
        onDrop={handleDrop}
        className={`border rounded p-3 text-center${
          isDragOver ? " border-primary bg-light" : " border-dashed"
        }${isInvalid ? " is-invalid border-danger" : ""}`}
        style={{ minHeight: "80px", transition: "background-color 0.15s" }}
      >
        {files.length === 0 ? (
          <div className="py-2">
            <div className="mb-2 text-secondary">
              <Icon icon="folder" size="3x" />
            </div>
            <p className="mb-1 text-muted">
              <FormattedMessage
                id="components.FileDropzone.dropzonePrompt"
                defaultMessage="Drag & drop files or folders here"
              />
            </p>
            <p className="mb-0 text-muted small">
              <FormattedMessage
                id="components.FileDropzone.dropzoneActions"
                defaultMessage="or {browseFiles} · {browseFolder}"
                values={{
                  browseFiles: (
                    <a
                      href="#"
                      onClick={(e) => {
                        e.preventDefault();
                        fileInputRef.current?.click();
                      }}
                    >
                      <FormattedMessage
                        id="components.FileDropzone.browseFiles"
                        defaultMessage="browse files"
                      />
                    </a>
                  ),
                  browseFolder: (
                    <a
                      href="#"
                      onClick={(e) => {
                        e.preventDefault();
                        folderInputRef.current?.click();
                      }}
                    >
                      <FormattedMessage
                        id="components.FileDropzone.browseFolders"
                        defaultMessage="browse folders"
                      />
                    </a>
                  ),
                }}
              />
            </p>
          </div>
        ) : (
          <>
            <div className="d-flex flex-wrap gap-1 justify-content-start text-start mb-2">
              {files.map((file, index) => (
                <Tag
                  key={`${getFileKey(file)}-${index}`}
                  className="d-inline-flex align-items-center gap-1 px-2"
                >
                  {getFileKey(file)}
                  <CloseButton
                    variant="white"
                    className="ms-1"
                    style={{ fontSize: "0.75em" }}
                    onClick={(e) => {
                      e.stopPropagation();
                      removeFile(index);
                    }}
                  />
                </Tag>
              ))}
            </div>
            <p className="mb-0 text-muted small">
              <FormattedMessage
                id="components.FileDropzone.fileSizeSummary"
                defaultMessage="{count} {count, plural, one {file} other {files}} selected — {size} total · {addFiles} · {addFolder} · {clearAll}"
                values={{
                  count: files.length,
                  size: formatFileSize(totalSize),
                  addFiles: (
                    <a
                      href="#"
                      onClick={(e) => {
                        e.preventDefault();
                        fileInputRef.current?.click();
                      }}
                    >
                      <FormattedMessage
                        id="components.FileDropzone.addMore"
                        defaultMessage="add files"
                      />
                    </a>
                  ),
                  addFolder: (
                    <a
                      href="#"
                      onClick={(e) => {
                        e.preventDefault();
                        folderInputRef.current?.click();
                      }}
                    >
                      <FormattedMessage
                        id="components.FileDropzone.addFolders"
                        defaultMessage="add folders"
                      />
                    </a>
                  ),
                  clearAll: (
                    <a
                      href="#"
                      onClick={(e) => {
                        e.preventDefault();
                        onChange([]);
                      }}
                    >
                      <FormattedMessage
                        id="components.FileDropzone.clearAll"
                        defaultMessage="clear all"
                      />
                    </a>
                  ),
                }}
              />
            </p>
          </>
        )}
      </div>
    </>
  );
};

export default FileDropzone;
