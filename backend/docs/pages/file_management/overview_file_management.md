<!---
  Copyright 2026 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# File Management

Edgehog provides a comprehensive file management mechanism that allows remotely managing files on devices.
The file management system is flexible and not tied to a specific platform, supporting any [Edgehog runtime](devices_and_runtime.html)
which implements the appropriate file transfer interfaces.

## File Management Workflow

Edgehog organizes files into [Repositories](repositories.html), central locations that can store Files and serve as
sources for file distribution.

A typical workflow consists of the following steps:

1. Create a [Repository](repositories.html).
2. Upload one or more [Files](files.html) to the repository.
3. Distribute Files to devices using [File Download Requests](#file-download-requests) or
   by creating a [File Download Campaign](file_download_campaigns.html).

This approach enables centralized file distribution and version management across fleets of devices.

### Direct File Operations

In addition to repository-based downloads, Edgehog supports creating ad-hoc download requests from an individual
Device page. This is useful to transfer files directly to a specific device without creating a Repository first.

### Uploading Files From Devices

Devices can upload files back to Edgehog's object storage using [File Upload Requests](#file-upload-requests).

Uploaded files are stored in S3-compatible storage and are accessible from the Device page.

### Deleting Files

Files stored on devices can be removed using [File Delete Requests](#file-delete-requests).

---

## Core Concepts

This section describes the core concepts used by Edgehog's file management system.

Edgehog uses file-management names from the Device's perspective: a File Download Request asks a Device to download a
file, while File Upload Requests and File Delete Requests ask the Device to upload or delete files that are already
on the Device.

### Repository

A Repository is a centralized storage location for files that can be uploaded to [Devices](user_core_concepts.html#device).
Repositories provide a structured way to organize and manage files that are intended for distribution to devices.

Files stored in a Repository can be used as sources for File Download Requests, enabling consistent file distribution
across devices.

### File

A File represents a document or binary blob stored within a Repository. Each File has:

- **Name**: a user-friendly name for the File.
- **Size**: the uncompressed size in bytes that will be stored on the Device.

Files are the basic entities for `upload`, `download` and `delete` operations. They can be delivered to devices using
File Download Requests, and devices can upload files back to Edgehog using File Upload Requests (visible from the Device page).

---

## File Download Requests

A File Download Request instructs a Device to fetch a File and deliver it to one of three destination types:

- **Storage**: persist the file on the Device's storage.
- **Streaming**: process the file without storing it on the Device.
- **Filesystem**: write the file to a path on the Device filesystem.

Requests can target a single Device (manual request) or be created in bulk as part of a campaign.

### Encoding Support

File Download Requests support different encoding options to optimize transfer bandwidth and device processing:

- **None**: no encoding; the file is transferred as-is.
- **gzip**: the file is compressed with gzip for transfer.
- **lz4**: the file is compressed with lz4 for transfer.

Which encodings are available depends on the device's declared capabilities and the runtime support on the device.

---

## File Upload Requests

A File Upload Request instructs a Device to send a file back to Edgehog's object storage (S3-compatible).

The value depends on the selected source type:

- for `STORAGE` you can select from one of the Files available in the List,
- for `FILESYSTEM` it is a path of a file on the device.

## File Delete Requests

A File Delete Request instructs a Device to remove a file from local storage.
Devices may refuse to delete files that are in use, when `force` is `false`. Forcing deletion can cause application errors or instability, use only when necessary.
