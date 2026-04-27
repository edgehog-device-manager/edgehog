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

const BLOCK_SIZE = 512;

const formatFileSize = (bytes: number): string => {
  if (bytes === 0) return "0 B";

  const k = 1024;
  const sizes = ["B", "KiB", "MiB", "GiB", "TiB"];

  const i = Math.min(
    Math.floor(Math.log(bytes) / Math.log(k)),
    sizes.length - 1,
  );

  const value = bytes / Math.pow(k, i);

  return `${i === 0 ? value : value.toFixed(1).replace(/\.0$/, "")} ${sizes[i]}`;
};

// Returns the path to use as the tar entry name.
// Uses webkitRelativePath (set by folder selection) when available,
// falling back to the file name for individually selected files.
const getTarEntryPath = (file: File): string =>
  file.webkitRelativePath || file.name;

const writeTarDirectoryEntry = (dirPath: string, chunks: BlobPart[]): void => {
  const header = new Uint8Array(BLOCK_SIZE);
  const encoder = new TextEncoder();

  header.set(encoder.encode(dirPath).slice(0, 100), 0);
  header.set(encoder.encode("0000755\0"), 100); // rwxr-xr-x
  header.set(encoder.encode("0000000\0"), 108);
  header.set(encoder.encode("0000000\0"), 116);
  header.set(encoder.encode("00000000000\0"), 124); // size 0
  const mtime = Math.floor(Date.now() / 1000)
    .toString(8)
    .padStart(11, "0");
  header.set(encoder.encode(mtime + "\0"), 136);
  header.set(encoder.encode("        "), 148); // placeholder checksum
  header[156] = 0x35; // ASCII '5' = directory
  header.set(encoder.encode("ustar\0"), 257);
  header.set(encoder.encode("00"), 263);

  let checksum = 0;
  for (let i = 0; i < BLOCK_SIZE; i++) checksum += header[i];
  header.set(
    encoder.encode(checksum.toString(8).padStart(6, "0") + "\0 "),
    148,
  );

  chunks.push(header);
};

// Creates a tar archive from an array of files.
// Returns a Blob containing the raw tar data (uncompressed).
const createTarArchive = (files: File[]): Blob => {
  const chunks: BlobPart[] = [];

  const directories = new Set<string>();
  for (const file of files) {
    const entryPath = getTarEntryPath(file);
    const parts = entryPath.split("/");
    for (let i = 1; i < parts.length; i++) {
      directories.add(parts.slice(0, i).join("/") + "/");
    }
  }

  for (const dirPath of [...directories].sort()) {
    writeTarDirectoryEntry(dirPath, chunks);
  }

  for (const file of files) {
    const fileName = getTarEntryPath(file);

    // Build the 512-byte tar header
    const header = new Uint8Array(BLOCK_SIZE);
    const encoder = new TextEncoder();

    // File name (offset 0, 100 bytes)
    const nameBytes = encoder.encode(fileName);
    header.set(nameBytes.slice(0, 100), 0);

    // File mode (offset 100, 8 bytes) - 0000644
    header.set(encoder.encode("0000644\0"), 100);

    // Owner ID (offset 108, 8 bytes) - 0000000
    header.set(encoder.encode("0000000\0"), 108);

    // Group ID (offset 116, 8 bytes) - 0000000
    header.set(encoder.encode("0000000\0"), 116);

    // File size in octal (offset 124, 12 bytes)
    const sizeOctal = file.size.toString(8).padStart(11, "0");
    header.set(encoder.encode(sizeOctal + "\0"), 124);

    // Modification time in octal (offset 136, 12 bytes)
    const mtime = Math.floor((file.lastModified || Date.now()) / 1000)
      .toString(8)
      .padStart(11, "0");
    header.set(encoder.encode(mtime + "\0"), 136);

    // Initialize checksum field with spaces (offset 148, 8 bytes)
    header.set(encoder.encode("        "), 148);

    // Type flag (offset 156, 1 byte) - '0' = regular file
    header[156] = 0x30; // ASCII '0'

    // USTAR indicator (offset 257, 6 bytes)
    header.set(encoder.encode("ustar\0"), 257);

    // USTAR version (offset 263, 2 bytes)
    header.set(encoder.encode("00"), 263);

    // Compute checksum: sum of all bytes in the header treated as unsigned
    let checksum = 0;
    for (let i = 0; i < BLOCK_SIZE; i++) {
      checksum += header[i];
    }
    const checksumStr = checksum.toString(8).padStart(6, "0") + "\0 ";
    header.set(encoder.encode(checksumStr), 148);

    chunks.push(header);
    chunks.push(file);

    // Pad file data to a multiple of 512 bytes
    const remainder = file.size % BLOCK_SIZE;
    if (remainder > 0) {
      chunks.push(new Uint8Array(BLOCK_SIZE - remainder));
    }
  }

  // End-of-archive marker: two 512-byte blocks of zeros
  chunks.push(new Uint8Array(BLOCK_SIZE * 2));

  return new Blob(chunks, { type: "application/x-tar" });
};

export { createTarArchive, formatFileSize };
