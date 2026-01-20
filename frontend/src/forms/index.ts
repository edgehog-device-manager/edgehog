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
    id: "fieldExplanation.imageReference.title",
    defaultMessage: "Image Reference",
  },
  imageReferenceDescription: {
    id: "fieldExplanation.imageReference.description",
    defaultMessage:
      "The complete reference for the container image you want to use, including registry, repository, and tag.",
  },
  imageReferenceExample: {
    id: "fieldExplanation.imageReference.example",
    defaultMessage: "my-image:latest or registry.example.com/my-app:v1.0",
  },
  imageCredentialsTitle: {
    id: "fieldExplanation.imageCredentials.title",
    defaultMessage: "Image Credentials",
  },
  imageCredentialsDescription: {
    id: "fieldExplanation.imageCredentials.description",
    defaultMessage:
      "Select credentials needed to pull this image from a private registry. Leave empty for public images.",
  },
  hostnameTitle: {
    id: "fieldExplanation.hostname.title",
    defaultMessage: "Hostname",
  },
  hostnameDescription: {
    id: "fieldExplanation.hostname.description",
    defaultMessage:
      "The network hostname to assign to the container, which must comply with RFC 1123.",
  },
  hostnameExample: {
    id: "fieldExplanation.hostname.example",
    defaultMessage: "web-server-1",
  },
  restartPolicyTitle: {
    id: "fieldExplanation.restartPolicy.title",
    defaultMessage: "Restart Policy",
  },
  restartPolicyDescription: {
    id: "fieldExplanation.restartPolicy.description",
    defaultMessage:
      "Defines container restart behavior. Options: 'no' (never restart), 'always', 'unless-stopped', 'on-failure'.",
  },
  restartPolicyExample: {
    id: "fieldExplanation.restartPolicy.example",
    defaultMessage: "unless-stopped",
  },
  networkModeTitle: {
    id: "fieldExplanation.networkMode.title",
    defaultMessage: "Network Mode",
  },
  networkModeDescription: {
    id: "fieldExplanation.networkMode.description",
    defaultMessage:
      "Supported standard values are: bridge, host, none, and container:'<name|id>'. Any other value is treated as the name of a user-defined network. Other container engines may support additional modes.",
  },
  networkModeExample: {
    id: "fieldExplanation.networkMode.example",
    defaultMessage: "bridge",
  },
  networksTitle: {
    id: "fieldExplanation.networks.title",
    defaultMessage: "Attached Networks",
  },
  networksDescription: {
    id: "fieldExplanation.networks.description",
    defaultMessage:
      "Select custom networks the container should connect to, usually for inter-service communication.",
  },
  portBindingsTitle: {
    id: "fieldExplanation.portBindings.title",
    defaultMessage: "Port Bindings",
  },
  portBindingsDescription: {
    id: "fieldExplanation.portBindings.description",
    defaultMessage:
      "Maps host ports to container ports for external access. Format: [host_port:]container_port[/protocol]. Protocol defaults to TCP.",
  },
  portBindingsExample: {
    id: "fieldExplanation.portBindings.example",
    defaultMessage: '"8080:80" or "8080:443/udp"',
  },
  bindsTitle: {
    id: "fieldExplanation.binds.title",
    defaultMessage: "Binds",
  },
  bindsDescription: {
    id: "fieldExplanation.binds.description",
    defaultMessage:
      "Maps host directories to container directories for persistent storage or sharing. Format: /host/path:/container/path[:ro|rw]",
  },
  bindsExample: {
    id: "fieldExplanation.binds.example",
    defaultMessage: "/data:/data or /config:/config:ro",
  },
  extraHostsTitle: {
    id: "fieldExplanation.extraHosts.title",
    defaultMessage: "Extra Hosts",
  },
  extraHostsDescription: {
    id: "fieldExplanation.extraHosts.description",
    defaultMessage:
      "List of hostname/IP mappings added to the container's /etc/hosts for custom DNS resolution. 'host-gateway' resolves to the host IP.",
  },
  extraHostsExample: {
    id: "fieldExplanation.extraHosts.example",
    defaultMessage: '"database:192.168.1.5" or "gateway:host-gateway"',
  },
  memoryTitle: {
    id: "fieldExplanation.memory.title",
    defaultMessage: "Memory Limit (bytes)",
  },
  memoryDescription: {
    id: "fieldExplanation.memory.description",
    defaultMessage:
      "Maximum physical memory the container can use. Set 0 for unlimited memory.",
  },
  memoryExample: {
    id: "fieldExplanation.memory.example",
    defaultMessage: "104857600 (100MB)",
  },
  memoryReservationTitle: {
    id: "fieldExplanation.memoryReservation.title",
    defaultMessage: "Memory Reservation (bytes)",
  },
  memoryReservationDescription: {
    id: "fieldExplanation.memoryReservation.description",
    defaultMessage:
      "Allows you to specify a soft limit smaller than Memory which is activated when Docker detects contention or low memory on the host machine. " +
      "If you use Memory Reservation, it must be set lower than Memory for it to take precedence. " +
      "Because it is a soft limit, it doesn't guarantee that the container doesn't exceed the limit.",
  },
  memoryReservationExample: {
    id: "fieldExplanation.memoryReservation.example",
    defaultMessage: "104857600 (100MB)",
  },
  memorySwapTitle: {
    id: "fieldExplanation.memorySwap.title",
    defaultMessage: "Memory + Swap Limit (bytes)",
  },
  memorySwapDescription: {
    id: "fieldExplanation.memorySwap.description",
    defaultMessage:
      "The total amount of memory plus swap the container can use. If memorySwap is set to a positive value, both Memory and Memory Swap must be set. " +
      "Memory controls the amount of physical memory, and Memory Swap represents the combined limit of memory and swap. " +
      "For example, if memory='300m' and memorySwap='1g', the container can use 300MB of memory and 700MB of swap (1GB - 300MB).",
  },
  memorySwapExample: {
    id: "fieldExplanation.memorySwap.example",
    defaultMessage: "1073741824 (1GB)",
  },
  memorySwappinessTitle: {
    id: "fieldExplanation.memorySwappiness.title",
    defaultMessage: "Memory Swappiness (0-100)",
  },
  memorySwappinessDescription: {
    id: "fieldExplanation.memorySwappiness.description",
    defaultMessage:
      "Controls kernel swap behavior. 0 = avoid swapping, 100 = swap aggressively.",
  },
  memorySwappinessExample: {
    id: "fieldExplanation.memorySwappiness.example",
    defaultMessage: "60",
  },
  cpuPeriodTitle: {
    id: "fieldExplanation.cpuPeriod.title",
    defaultMessage: "CPU Period (microseconds)",
  },
  cpuPeriodDescription: {
    id: "fieldExplanation.cpuPeriod.description",
    defaultMessage:
      "Duration of a CPU scheduling period. Used with CPU Quota to limit CPU usage.",
  },
  cpuPeriodExample: {
    id: "fieldExplanation.cpuPeriod.example",
    defaultMessage: "100000",
  },
  cpuQuotaTitle: {
    id: "fieldExplanation.cpuQuota.title",
    defaultMessage: "CPU Quota (microseconds)",
  },
  cpuQuotaDescription: {
    id: "fieldExplanation.cpuQuota.description",
    defaultMessage:
      "CPU time allowed per period. Example: quota 50000 with period 100000 → 50% of one CPU.",
  },
  cpuQuotaExample: {
    id: "fieldExplanation.cpuQuota.example",
    defaultMessage: "50000",
  },
  cpuRealtimePeriodTitle: {
    id: "fieldExplanation.cpuRealtimePeriod.title",
    defaultMessage: "CPU Real-Time Period (microseconds)",
  },
  cpuRealtimePeriodDescription: {
    id: "fieldExplanation.cpuRealtimePeriod.description",
    defaultMessage:
      "Scheduling period for CPU time dedicated to real-time tasks. Set to 0 to allocate no time allocated to real-time tasks.",
  },
  cpuRealtimePeriodExample: {
    id: "fieldExplanation.cpuRealtimePeriod.example",
    defaultMessage: "1000000",
  },
  cpuRealtimeRuntimeTitle: {
    id: "fieldExplanation.cpuRealtimeRuntime.title",
    defaultMessage: "CPU Real-Time Runtime (microseconds)",
  },
  cpuRealtimeRuntimeDescription: {
    id: "fieldExplanation.cpuRealtimeRuntime.description",
    defaultMessage:
      "Max real-time CPU time within the real-time period. Cannot exceed the real-time period.",
  },
  cpuRealtimeRuntimeExample: {
    id: "fieldExplanation.cpuRealtimeRuntime.example",
    defaultMessage: "950000",
  },
  envTitle: {
    id: "fieldExplanation.env.title",
    defaultMessage: "Environment Variables (JSON String)",
  },
  envDescription: {
    id: "fieldExplanation.env.description",
    defaultMessage:
      "JSON array of environment variables in 'KEY=VALUE' format, used to pass config to the containerized app.",
  },
  envExample: {
    id: "fieldExplanation.env.example",
    defaultMessage: '["NODE_ENV=production", "PORT=8080"]',
  },
  volumesTitle: {
    id: "fieldExplanation.volumes.title",
    defaultMessage: "Volume Mounts",
  },
  volumesDescription: {
    id: "fieldExplanation.volumes.description",
    defaultMessage:
      "Attach an existing volume to a path inside the container. This allows the container to persist data or share it with other containers. " +
      "You only need to select the volume and provide the container path where it will be mounted.",
  },
  volumesExample: {
    id: "fieldExplanation.volumes.example",
    defaultMessage: "my-named-volume:/app/data",
  },
  privilegedTitle: {
    id: "fieldExplanation.privileged.title",
    defaultMessage: "Privileged Mode",
  },
  privilegedDescription: {
    id: "fieldExplanation.privileged.description",
    defaultMessage:
      "Run container with extended privileges, giving full host resource access (like root).",
  },
  readOnlyRootfsTitle: {
    id: "fieldExplanation.readOnlyRootfs.title",
    defaultMessage: "Read-Only Root Filesystem",
  },
  readOnlyRootfsDescription: {
    id: "fieldExplanation.readOnlyRootfs.description",
    defaultMessage:
      "Prevents modification of system files by making the container's root filesystem read-only.",
  },
  storageOptTitle: {
    id: "fieldExplanation.storageOpt.title",
    defaultMessage: "Storage Options",
  },
  storageOptDescription: {
    id: "fieldExplanation.storageOpt.description",
    defaultMessage:
      "Driver-specific storage options, such as limiting the size of the writable layer.",
  },
  storageOptExample: {
    id: "fieldExplanation.storageOpt.example",
    defaultMessage: '"size=100G"',
  },
  tmpfsTitle: {
    id: "fieldExplanation.tmpfs.title",
    defaultMessage: "Tmpfs Mounts",
  },
  tmpfsDescription: {
    id: "fieldExplanation.tmpfs.description",
    defaultMessage:
      "In-memory filesystems mounted at specified container paths. Data is fast but lost on container restart.",
  },
  tmpfsExample: {
    id: "fieldExplanation.tmpfs.example",
    defaultMessage: '"/tmp:size=64m"',
  },
  capAddTitle: {
    id: "fieldExplanation.capAdd.title",
    defaultMessage: "Add Capabilities (Cap Add)",
  },
  capAddDescription: {
    id: "fieldExplanation.capAdd.description",
    defaultMessage:
      "Add Linux kernel capabilities to the container, e.g., 'NET_ADMIN' for network management.",
  },
  capAddExample: {
    id: "fieldExplanation.capAdd.example",
    defaultMessage: '["NET_ADMIN", "SYS_ADMIN"]',
  },
  capDropTitle: {
    id: "fieldExplanation.capDrop.title",
    defaultMessage: "Drop Capabilities (Cap Drop)",
  },
  capDropDescription: {
    id: "fieldExplanation.capDrop.description",
    defaultMessage:
      "Remove default Linux kernel capabilities to improve container security.",
  },
  capDropExample: {
    id: "fieldExplanation.capDrop.example",
    defaultMessage: '["MKNOD", "SETPCAP"]',
  },
  volumeDriverTitle: {
    id: "fieldExplanation.volumeDriver.title",
    defaultMessage: "Volume Driver",
  },
  volumeDriverDescription: {
    id: "fieldExplanation.volumeDriver.description",
    defaultMessage: "Driver/plugin used to manage and mount volumes.",
  },
  volumeDriverExample: {
    id: "fieldExplanation.volumeDriver.example",
    defaultMessage: "local",
  },
  deviceMappingsTitle: {
    id: "fieldExplanation.deviceMappings.title",
    defaultMessage: "Device Mappings",
  },
  deviceMappingsDescription: {
    id: "fieldExplanation.deviceMappings.description",
    defaultMessage:
      "Maps host devices to container paths with specific access permissions.",
  },
  deviceMappingsExample: {
    id: "fieldExplanation.deviceMappings.example",
    defaultMessage:
      '[("pathOnHost":"/dev/sda1","pathInContainer":"/dev/storage","cGroupPermissions":"mrw")]',
  },
});

export { fieldExplanations };
