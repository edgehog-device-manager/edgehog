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

import { gzip } from "fflate";

const BLOCK_SIZE = 512;

// Computes a SHA-256 digest of binary data using the Web Crypto API.
// Returns the digest in the format "sha256:<hex>".
const computeDigest = async (data: Uint8Array): Promise<string> => {
  const hashBuffer = await crypto.subtle.digest(
    "SHA-256",
    data.buffer as ArrayBuffer,
  );
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `sha256:${hashHex}`;
};

// Creates a tar archive from an array of files.
// Returns a Uint8Array containing the raw tar data (uncompressed).
const createTarArchive = async (files: File[]): Promise<Uint8Array> => {
  const chunks: Uint8Array[] = [];

  for (const file of files) {
    const fileData = new Uint8Array(await file.arrayBuffer());
    const fileName = file.name;

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
    const sizeOctal = fileData.length.toString(8).padStart(11, "0");
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
    chunks.push(fileData);

    // Pad file data to a multiple of 512 bytes
    const remainder = fileData.length % BLOCK_SIZE;
    if (remainder > 0) {
      chunks.push(new Uint8Array(BLOCK_SIZE - remainder));
    }
  }

  // End-of-archive marker: two 512-byte blocks of zeros
  chunks.push(new Uint8Array(BLOCK_SIZE * 2));

  // Concatenate all chunks
  const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const tarData = new Uint8Array(totalLength);
  let offset = 0;
  for (const chunk of chunks) {
    tarData.set(chunk, offset);
    offset += chunk.length;
  }

  return tarData;
};

// Creates a tar.gz archive from multiple files.
// Returns a Blob of the compressed archive.
const createTarGzArchive = async (files: File[]): Promise<Blob> => {
  const tarData = await createTarArchive(files);
  const gzippedData = await new Promise<Uint8Array>((resolve, reject) => {
    gzip(tarData, (err, data) => {
      if (err) reject(err);
      else resolve(data);
    });
  });
  return new Blob([gzippedData.buffer as ArrayBuffer], {
    type: "application/gzip",
  });
};

export { computeDigest, createTarArchive, createTarGzArchive };
