/*
 * This file is part of Edgehog.
 *
 * Copyright 2021 - 2026 SECO Mind Srl
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

import { defineMessages } from "react-intl";

/* ----------------------------- Field Explanations ----------------------------- */
const fieldExplanations = defineMessages({
  imageReferenceTitle: {
    id: "forms.fieldExplanation.imageReference.title",
    defaultMessage: "Image Reference",
  },
  imageReferenceDescription: {
    id: "forms.fieldExplanation.imageReference.description",
    defaultMessage:
      "The complete reference for the container image you want to use, including registry, repository, and tag.",
  },
  imageReferenceExample: {
    id: "forms.fieldExplanation.imageReference.example",
    defaultMessage: "my-image:latest or registry.example.com/my-app:v1.0",
  },
  imageCredentialsTitle: {
    id: "forms.fieldExplanation.imageCredentials.title",
    defaultMessage: "Image Credentials",
  },
  imageCredentialsDescription: {
    id: "forms.fieldExplanation.imageCredentials.description",
    defaultMessage:
      "Select credentials needed to pull this image from a private registry. Leave empty for public images.",
  },
  hostnameTitle: {
    id: "forms.fieldExplanation.hostname.title",
    defaultMessage: "Hostname",
  },
  hostnameDescription: {
    id: "forms.fieldExplanation.hostname.description",
    defaultMessage:
      "The network hostname to assign to the container, which must comply with RFC 1123.",
  },
  hostnameExample: {
    id: "forms.fieldExplanation.hostname.example",
    defaultMessage: "web-server-1",
  },
  restartPolicyTitle: {
    id: "forms.fieldExplanation.restartPolicy.title",
    defaultMessage: "Restart Policy",
  },
  restartPolicyDescription: {
    id: "forms.fieldExplanation.restartPolicy.description",
    defaultMessage:
      "Defines container restart behavior. Options: 'no' (never restart), 'always', 'unless-stopped', 'on-failure'.",
  },
  restartPolicyExample: {
    id: "forms.fieldExplanation.restartPolicy.example",
    defaultMessage: "unless-stopped",
  },
  networkModeTitle: {
    id: "forms.fieldExplanation.networkMode.title",
    defaultMessage: "Network Mode",
  },
  networkModeDescription: {
    id: "forms.fieldExplanation.networkMode.description",
    defaultMessage:
      "Supported standard values are: bridge, host, none, and container:'<name|id>'. Any other value is treated as the name of a user-defined network. Other container engines may support additional modes.",
  },
  networkModeExample: {
    id: "forms.fieldExplanation.networkMode.example",
    defaultMessage: "bridge",
  },
  networksTitle: {
    id: "forms.fieldExplanation.networks.title",
    defaultMessage: "Attached Networks",
  },
  networksDescription: {
    id: "forms.fieldExplanation.networks.description",
    defaultMessage:
      "Select custom networks the container should connect to, usually for inter-service communication.",
  },
  portBindingsTitle: {
    id: "forms.fieldExplanation.portBindings.title",
    defaultMessage: "Port Bindings",
  },
  portBindingsDescription: {
    id: "forms.fieldExplanation.portBindings.description",
    defaultMessage:
      "Maps host ports to container ports for external access. Format: [host_port:]container_port[/protocol]. Protocol defaults to TCP.",
  },
  portBindingsExample: {
    id: "forms.fieldExplanation.portBindings.example",
    defaultMessage: '"8080:80" or "8080:443/udp"',
  },
  bindsTitle: {
    id: "forms.fieldExplanation.binds.title",
    defaultMessage: "Binds",
  },
  bindsDescription: {
    id: "forms.fieldExplanation.binds.description",
    defaultMessage:
      "Maps host directories to container directories for persistent storage or sharing. Format: /host/path:/container/path[:ro|rw]",
  },
  bindsExample: {
    id: "forms.fieldExplanation.binds.example",
    defaultMessage: "/data:/data or /config:/config:ro",
  },
  extraHostsTitle: {
    id: "forms.fieldExplanation.extraHosts.title",
    defaultMessage: "Extra Hosts",
  },
  extraHostsDescription: {
    id: "forms.fieldExplanation.extraHosts.description",
    defaultMessage:
      "List of hostname/IP mappings added to the container's /etc/hosts for custom DNS resolution. 'host-gateway' resolves to the host IP.",
  },
  extraHostsExample: {
    id: "forms.fieldExplanation.extraHosts.example",
    defaultMessage: '"database:192.168.1.5" or "gateway:host-gateway"',
  },
  memoryTitle: {
    id: "forms.fieldExplanation.memory.title",
    defaultMessage: "Memory Limit (bytes)",
  },
  memoryDescription: {
    id: "forms.fieldExplanation.memory.description",
    defaultMessage:
      "Maximum physical memory the container can use. Set 0 for unlimited memory.",
  },
  memoryExample: {
    id: "forms.fieldExplanation.memory.example",
    defaultMessage: "104857600 (100MB)",
  },
  memoryReservationTitle: {
    id: "forms.fieldExplanation.memoryReservation.title",
    defaultMessage: "Memory Reservation (bytes)",
  },
  memoryReservationDescription: {
    id: "forms.fieldExplanation.memoryReservation.description",
    defaultMessage:
      "Allows you to specify a soft limit smaller than Memory which is activated when Docker detects contention or low memory on the host machine. " +
      "If you use Memory Reservation, it must be set lower than Memory for it to take precedence. " +
      "Because it is a soft limit, it doesn't guarantee that the container doesn't exceed the limit.",
  },
  memoryReservationExample: {
    id: "forms.fieldExplanation.memoryReservation.example",
    defaultMessage: "104857600 (100MB)",
  },
  memorySwapTitle: {
    id: "forms.fieldExplanation.memorySwap.title",
    defaultMessage: "Memory + Swap Limit (bytes)",
  },
  memorySwapDescription: {
    id: "forms.fieldExplanation.memorySwap.description",
    defaultMessage:
      "The total amount of memory plus swap the container can use. If memorySwap is set to a positive value, both Memory and Memory Swap must be set. " +
      "Memory controls the amount of physical memory, and Memory Swap represents the combined limit of memory and swap. " +
      "For example, if memory='300m' and memorySwap='1g', the container can use 300MB of memory and 700MB of swap (1GB - 300MB).",
  },
  memorySwapExample: {
    id: "forms.fieldExplanation.memorySwap.example",
    defaultMessage: "1073741824 (1GB)",
  },
  memorySwappinessTitle: {
    id: "forms.fieldExplanation.memorySwappiness.title",
    defaultMessage: "Memory Swappiness (0-100)",
  },
  memorySwappinessDescription: {
    id: "forms.fieldExplanation.memorySwappiness.description",
    defaultMessage:
      "Controls kernel swap behavior. 0 = avoid swapping, 100 = swap aggressively.",
  },
  memorySwappinessExample: {
    id: "forms.fieldExplanation.memorySwappiness.example",
    defaultMessage: "60",
  },
  cpuPeriodTitle: {
    id: "forms.fieldExplanation.cpuPeriod.title",
    defaultMessage: "CPU Period (microseconds)",
  },
  cpuPeriodDescription: {
    id: "forms.fieldExplanation.cpuPeriod.description",
    defaultMessage:
      "Duration of a CPU scheduling period. Used with CPU Quota to limit CPU usage.",
  },
  cpuPeriodExample: {
    id: "forms.fieldExplanation.cpuPeriod.example",
    defaultMessage: "100000",
  },
  cpuQuotaTitle: {
    id: "forms.fieldExplanation.cpuQuota.title",
    defaultMessage: "CPU Quota (microseconds)",
  },
  cpuQuotaDescription: {
    id: "forms.fieldExplanation.cpuQuota.description",
    defaultMessage:
      "CPU time allowed per period. Example: quota 50000 with period 100000 → 50% of one CPU.",
  },
  cpuQuotaExample: {
    id: "forms.fieldExplanation.cpuQuota.example",
    defaultMessage: "50000",
  },
  cpuRealtimePeriodTitle: {
    id: "forms.fieldExplanation.cpuRealtimePeriod.title",
    defaultMessage: "CPU Real-Time Period (microseconds)",
  },
  cpuRealtimePeriodDescription: {
    id: "forms.fieldExplanation.cpuRealtimePeriod.description",
    defaultMessage:
      "Scheduling period for CPU time dedicated to real-time tasks. Set to 0 to allocate no time allocated to real-time tasks.",
  },
  cpuRealtimePeriodExample: {
    id: "forms.fieldExplanation.cpuRealtimePeriod.example",
    defaultMessage: "1000000",
  },
  cpuRealtimeRuntimeTitle: {
    id: "forms.fieldExplanation.cpuRealtimeRuntime.title",
    defaultMessage: "CPU Real-Time Runtime (microseconds)",
  },
  cpuRealtimeRuntimeDescription: {
    id: "forms.fieldExplanation.cpuRealtimeRuntime.description",
    defaultMessage:
      "Max real-time CPU time within the real-time period. Cannot exceed the real-time period.",
  },
  cpuRealtimeRuntimeExample: {
    id: "forms.fieldExplanation.cpuRealtimeRuntime.example",
    defaultMessage: "950000",
  },
  envTitle: {
    id: "forms.fieldExplanation.env.title",
    defaultMessage: "Environment Variables (JSON String)",
  },
  envDescription: {
    id: "forms.fieldExplanation.env.description",
    defaultMessage:
      "JSON array of environment variables in 'KEY=VALUE' format, used to pass config to the containerized app.",
  },
  envExample: {
    id: "forms.fieldExplanation.env.example",
    defaultMessage: '["NODE_ENV=production", "PORT=8080"]',
  },
  volumesTitle: {
    id: "forms.fieldExplanation.volumes.title",
    defaultMessage: "Volume Mounts",
  },
  volumesDescription: {
    id: "forms.fieldExplanation.volumes.description",
    defaultMessage:
      "Attach an existing volume to a path inside the container. This allows the container to persist data or share it with other containers. " +
      "You only need to select the volume and provide the container path where it will be mounted.",
  },
  volumesExample: {
    id: "forms.fieldExplanation.volumes.example",
    defaultMessage: "my-named-volume:/app/data",
  },
  privilegedTitle: {
    id: "forms.fieldExplanation.privileged.title",
    defaultMessage: "Privileged Mode",
  },
  privilegedDescription: {
    id: "forms.fieldExplanation.privileged.description",
    defaultMessage:
      "Run container with extended privileges, giving full host resource access (like root).",
  },
  readOnlyRootfsTitle: {
    id: "forms.fieldExplanation.readOnlyRootfs.title",
    defaultMessage: "Read-Only Root Filesystem",
  },
  readOnlyRootfsDescription: {
    id: "forms.fieldExplanation.readOnlyRootfs.description",
    defaultMessage:
      "Prevents modification of system files by making the container's root filesystem read-only.",
  },
  storageOptTitle: {
    id: "forms.fieldExplanation.storageOpt.title",
    defaultMessage: "Storage Options",
  },
  storageOptDescription: {
    id: "forms.fieldExplanation.storageOpt.description",
    defaultMessage:
      "Driver-specific storage options, such as limiting the size of the writable layer.",
  },
  storageOptExample: {
    id: "forms.fieldExplanation.storageOpt.example",
    defaultMessage: '"size=100G"',
  },
  tmpfsTitle: {
    id: "forms.fieldExplanation.tmpfs.title",
    defaultMessage: "Tmpfs Mounts",
  },
  tmpfsDescription: {
    id: "forms.fieldExplanation.tmpfs.description",
    defaultMessage:
      "In-memory filesystems mounted at specified container paths. Data is fast but lost on container restart.",
  },
  tmpfsExample: {
    id: "forms.fieldExplanation.tmpfs.example",
    defaultMessage: '"/tmp:size=64m"',
  },
  capAddTitle: {
    id: "forms.fieldExplanation.capAdd.title",
    defaultMessage: "Add Capabilities (Cap Add)",
  },
  capAddDescription: {
    id: "forms.fieldExplanation.capAdd.description",
    defaultMessage:
      "Add Linux kernel capabilities to the container, e.g., 'NET_ADMIN' for network management.",
  },
  capAddExample: {
    id: "forms.fieldExplanation.capAdd.example",
    defaultMessage: '["NET_ADMIN", "SYS_ADMIN"]',
  },
  capDropTitle: {
    id: "forms.fieldExplanation.capDrop.title",
    defaultMessage: "Drop Capabilities (Cap Drop)",
  },
  capDropDescription: {
    id: "forms.fieldExplanation.capDrop.description",
    defaultMessage:
      "Remove default Linux kernel capabilities to improve container security.",
  },
  capDropExample: {
    id: "forms.fieldExplanation.capDrop.example",
    defaultMessage: '["MKNOD", "SETPCAP"]',
  },
  volumeDriverTitle: {
    id: "forms.fieldExplanation.volumeDriver.title",
    defaultMessage: "Volume Driver",
  },
  volumeDriverDescription: {
    id: "forms.fieldExplanation.volumeDriver.description",
    defaultMessage: "Driver/plugin used to manage and mount volumes.",
  },
  volumeDriverExample: {
    id: "forms.fieldExplanation.volumeDriver.example",
    defaultMessage: "local",
  },
  deviceMappingsTitle: {
    id: "forms.fieldExplanation.deviceMappings.title",
    defaultMessage: "Device Mappings",
  },
  deviceMappingsDescription: {
    id: "forms.fieldExplanation.deviceMappings.description",
    defaultMessage:
      "Maps host devices to container paths with specific access permissions.",
  },
  deviceMappingsExample: {
    id: "forms.fieldExplanation.deviceMappings.example",
    defaultMessage:
      '[("pathOnHost":"/dev/sda1","pathInContainer":"/dev/storage","cGroupPermissions":"mrw")]',
  },
  driverTitle: {
    id: "forms.fieldExplanation.deviceRequest.driver.title",
    defaultMessage: "Driver",
  },
  driverDescription: {
    id: "forms.fieldExplanation.deviceRequest.driver.description",
    defaultMessage:
      "The name of the Docker runtime driver plugin installed on the host system (for example 'nvidia' or 'cdi'). Leave empty to use the default Docker runtime if supported.",
  },
  driverExample: {
    id: "forms.fieldExplanation.deviceRequest.driver.example",
    defaultMessage: "nvidia",
  },
  countTitle: {
    id: "forms.fieldExplanation.deviceRequest.count.title",
    defaultMessage: "Count",
  },
  countDescription: {
    id: "forms.fieldExplanation.deviceRequest.count.description",
    defaultMessage:
      "The number of matching devices to assign to the container. Set to -1 to request all matching devices, or specify a positive number to let Docker automatically choose that many devices.",
  },
  countExample: {
    id: "forms.fieldExplanation.deviceRequest.count.example",
    defaultMessage: "-1",
  },
  deviceIDsTitle: {
    id: "forms.fieldExplanation.deviceRequest.deviceIds.title",
    defaultMessage: "Device IDs",
  },
  deviceIDsDescription: {
    id: "forms.fieldExplanation.deviceRequest.deviceIds.description",
    defaultMessage:
      "Request specific hardware devices instead of allowing Docker to automatically select them. When Device IDs are specified, Count should usually be omitted or set to 0.",
  },
  deviceIDsExample: {
    id: "forms.fieldExplanation.deviceRequest.deviceIds.example",
    defaultMessage: '["0", "2"]',
  },
  capabilitiesTitle: {
    id: "forms.fieldExplanation.deviceRequest.capabilities.title",
    defaultMessage: "Capabilities",
  },
  capabilitiesDescription: {
    id: "forms.fieldExplanation.deviceRequest.capabilities.description",
    defaultMessage:
      "Each row represents an OR condition. Comma-separated values within a row represent AND conditions. For example, 'gpu,compute' requires both capabilities, while separate rows such as 'gpu' and 'video' allow either capability.",
  },
  capabilitiesExample: {
    id: "forms.fieldExplanation.deviceRequest.capabilities.example",
    defaultMessage: "gpu,compute\nvideo",
  },
  driverOptionsTitle: {
    id: "forms.fieldExplanation.driverOptions.title",
    defaultMessage: "Driver Options",
  },
  driverOptionsDescription: {
    id: "forms.fieldExplanation.driverOptions.description",
    defaultMessage:
      "A key-value map passed directly to the underlying device driver plugin for runtime-specific constraints (such as minimum driver versions or environmental bindings)",
  },
  driverOptionsExample: {
    id: "forms.fieldExplanation.driverOptions.example",
    defaultMessage: '[("require.cuda": "12.2")]',
  },
  deviceRequestsTitle: {
    id: "forms.fieldExplanation.deviceRequest.title",
    defaultMessage: "Device Requests",
  },
  deviceRequestsDescription: {
    id: "forms.fieldExplanation.deviceRequest.description",
    defaultMessage:
      "Configure hardware device requirements for your container. Device requests allow you to specify a driver, required device count, device IDs, and capabilities.",
  },
  deviceRequestsExample: {
    id: "forms.fieldExplanation.deviceRequest.example",
    defaultMessage: "GPU device request: driver=nvidia, count=1",
  },
});

export { fieldExplanations };
