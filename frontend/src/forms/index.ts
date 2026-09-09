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
  commandTitle: {
    id: "forms.fieldExplanation.command.title",
    defaultMessage: "Command",
  },
  commandDescription: {
    id: "forms.fieldExplanation.command.description",
    defaultMessage:
      "Command to run as the container's main process, passed to the entrypoint. Space-separated arguments.",
  },
  commandExample: {
    id: "forms.fieldExplanation.command.example",
    defaultMessage: "cmd '<arg1> <arg2>' ...",
  },
  entrypointTitle: {
    id: "forms.fieldExplanation.entrypoint.title",
    defaultMessage: "Entrypoint",
  },
  entrypointDescription: {
    id: "forms.fieldExplanation.entrypoint.description",
    defaultMessage: "Override the default entry point of the container image.",
  },
  entrypointExample: {
    id: "forms.fieldExplanation.entrypoint.example",
    defaultMessage: "/path/to/entrypoint",
  },
  healthcheckTestTitle: {
    id: "forms.fieldExplanation.healthcheckTest.title",
    defaultMessage: "Healthcheck Test",
  },
  healthcheckTestDescription: {
    id: "forms.fieldExplanation.healthcheckTest.description",
    defaultMessage:
      "Test command to check container health. A non-zero exit code indicates the container is unhealthy.",
  },
  healthcheckTestExample: {
    id: "forms.fieldExplanation.healthcheckTest.example",
    defaultMessage: "CMD curl -f http://localhost",
  },
  healthcheckIntervalTitle: {
    id: "forms.fieldExplanation.healthcheckInterval.title",
    defaultMessage: "Healthcheck Interval",
  },
  healthcheckIntervalDescription: {
    id: "forms.fieldExplanation.healthcheckInterval.description",
    defaultMessage:
      "Time between health checks in nanoseconds. Must be 0 or at least 1,000,000 (1 ms). 0 means inherit the default.",
  },
  healthcheckIntervalExample: {
    id: "forms.fieldExplanation.healthcheckInterval.example",
    defaultMessage: "30000000000 (30s)",
  },
  healthcheckTimeoutTitle: {
    id: "forms.fieldExplanation.healthcheckTimeout.title",
    defaultMessage: "Healthcheck Timeout",
  },
  healthcheckTimeoutDescription: {
    id: "forms.fieldExplanation.healthcheckTimeout.description",
    defaultMessage:
      "Time to wait before considering a health check hung, in nanoseconds. Must be 0 or at least 1,000,000. 0 means inherit.",
  },
  healthcheckTimeoutExample: {
    id: "forms.fieldExplanation.healthcheckTimeout.example",
    defaultMessage: "10000000000 (10s)",
  },
  healthcheckRetriesTitle: {
    id: "forms.fieldExplanation.healthcheckRetries.title",
    defaultMessage: "Healthcheck Retries",
  },
  healthcheckRetriesDescription: {
    id: "forms.fieldExplanation.healthcheckRetries.description",
    defaultMessage:
      "Consecutive failures needed to mark the container as unhealthy. 0 means inherit.",
  },
  healthcheckRetriesExample: {
    id: "forms.fieldExplanation.healthcheckRetries.example",
    defaultMessage: "3",
  },
  healthcheckStartPeriodTitle: {
    id: "forms.fieldExplanation.healthcheckStartPeriod.title",
    defaultMessage: "Healthcheck Start Period",
  },
  healthcheckStartPeriodDescription: {
    id: "forms.fieldExplanation.healthcheckStartPeriod.description",
    defaultMessage:
      "Grace period after container start before health check retries begin, in nanoseconds. Must be 0 or at least 1,000,000. 0 means inherit.",
  },
  healthcheckStartPeriodExample: {
    id: "forms.fieldExplanation.healthcheckStartPeriod.example",
    defaultMessage: "5000000000 (5s)",
  },
  healthcheckStartIntervalTitle: {
    id: "forms.fieldExplanation.healthcheckStartInterval.title",
    defaultMessage: "Healthcheck Start Interval",
  },
  healthcheckStartIntervalDescription: {
    id: "forms.fieldExplanation.healthcheckStartInterval.description",
    defaultMessage:
      "Time between checks during the start period, in nanoseconds. Must be 0 or at least 1,000,000. 0 means inherit.",
  },
  healthcheckStartIntervalExample: {
    id: "forms.fieldExplanation.healthcheckStartInterval.example",
    defaultMessage: "5000000000 (5s)",
  },
  workingDirectoryTitle: {
    id: "forms.fieldExplanation.workingDirectory.title",
    defaultMessage: "Working Directory",
  },
  workingDirectoryDescription: {
    id: "forms.fieldExplanation.workingDirectory.description",
    defaultMessage:
      "Working directory inside the container for command execution.",
  },
  workingDirectoryExample: {
    id: "forms.fieldExplanation.workingDirectory.example",
    defaultMessage: "/app",
  },
  userTitle: {
    id: "forms.fieldExplanation.user.title",
    defaultMessage: "User",
  },
  userDescription: {
    id: "forms.fieldExplanation.user.description",
    defaultMessage:
      "User to run the container process as. Format: '<user-name|UID>'[:'<group-name|GID>'].",
  },
  userExample: {
    id: "forms.fieldExplanation.user.example",
    defaultMessage: "1000:1000",
  },
  domainnameTitle: {
    id: "forms.fieldExplanation.domainname.title",
    defaultMessage: "Domainname",
  },
  domainnameDescription: {
    id: "forms.fieldExplanation.domainname.description",
    defaultMessage: "Domain name to set for the container.",
  },
  domainnameExample: {
    id: "forms.fieldExplanation.domainname.example",
    defaultMessage: "example.com",
  },
  networkDisabledTitle: {
    id: "forms.fieldExplanation.networkDisabled.title",
    defaultMessage: "Disable Networking",
  },
  networkDisabledDescription: {
    id: "forms.fieldExplanation.networkDisabled.description",
    defaultMessage: "Disable all networking for the container.",
  },
  dnsTitle: {
    id: "forms.fieldExplanation.dns.title",
    defaultMessage: "DNS Servers",
  },
  dnsDescription: {
    id: "forms.fieldExplanation.dns.description",
    defaultMessage: "Custom DNS servers for the container.",
  },
  dnsExample: {
    id: "forms.fieldExplanation.dns.example",
    defaultMessage: "8.8.8.8",
  },
  dnsOptionsTitle: {
    id: "forms.fieldExplanation.dnsOptions.title",
    defaultMessage: "DNS Options",
  },
  dnsOptionsDescription: {
    id: "forms.fieldExplanation.dnsOptions.description",
    defaultMessage: "DNS resolver options (e.g. ndots:5).",
  },
  dnsOptionsExample: {
    id: "forms.fieldExplanation.dnsOptions.example",
    defaultMessage: "ndots:5",
  },
  dnsSearchTitle: {
    id: "forms.fieldExplanation.dnsSearch.title",
    defaultMessage: "DNS Search",
  },
  dnsSearchDescription: {
    id: "forms.fieldExplanation.dnsSearch.description",
    defaultMessage: "DNS search domains for short name resolution.",
  },
  dnsSearchExample: {
    id: "forms.fieldExplanation.dnsSearch.example",
    defaultMessage: "example.com",
  },
  exposedPortsTitle: {
    id: "forms.fieldExplanation.exposedPorts.title",
    defaultMessage: "Exposed Ports",
  },
  exposedPortsDescription: {
    id: "forms.fieldExplanation.exposedPorts.description",
    defaultMessage:
      "Ports to expose without publishing. Format: '<port>'/'<tcp|udp|sctp>'.",
  },
  exposedPortsExample: {
    id: "forms.fieldExplanation.exposedPorts.example",
    defaultMessage: "80/tcp",
  },
  autoRemoveTitle: {
    id: "forms.fieldExplanation.autoRemove.title",
    defaultMessage: "Auto Remove",
  },
  autoRemoveDescription: {
    id: "forms.fieldExplanation.autoRemove.description",
    defaultMessage:
      "Automatically remove the container filesystem when it exits.",
  },
  cpuSharesTitle: {
    id: "forms.fieldExplanation.cpuShares.title",
    defaultMessage: "CPU Shares",
  },
  cpuSharesDescription: {
    id: "forms.fieldExplanation.cpuShares.description",
    defaultMessage:
      "Relative CPU weight for the container compared to other containers.",
  },
  cpuSharesExample: {
    id: "forms.fieldExplanation.cpuShares.example",
    defaultMessage: "512",
  },
  cpusetCpusTitle: {
    id: "forms.fieldExplanation.cpusetCpus.title",
    defaultMessage: "Allowed CPUs sets",
  },
  cpusetCpusDescription: {
    id: "forms.fieldExplanation.cpusetCpus.description",
    defaultMessage: "CPUs on which to allow execution (e.g. 0-3,0,1).",
  },
  cpusetCpusExample: {
    id: "forms.fieldExplanation.cpusetCpus.example",
    defaultMessage: "0-3,0,1",
  },
  shmSizeTitle: {
    id: "forms.fieldExplanation.shmSize.title",
    defaultMessage: "Shared Memory Size",
  },
  shmSizeDescription: {
    id: "forms.fieldExplanation.shmSize.description",
    defaultMessage: "Size of /dev/shm in bytes. Default is 64 MB.",
  },
  shmSizeExample: {
    id: "forms.fieldExplanation.shmSize.example",
    defaultMessage: "67108864",
  },
  oomScoreAdjustmentTitle: {
    id: "forms.fieldExplanation.oomScoreAdjustment.title",
    defaultMessage: "OOM Score Adjustment",
  },
  oomScoreAdjustmentDescription: {
    id: "forms.fieldExplanation.oomScoreAdjustment.description",
    defaultMessage:
      "Adjust the OOM killer preference score. Range: -1000 to 1000.",
  },
  oomScoreAdjustmentExample: {
    id: "forms.fieldExplanation.oomScoreAdjustment.example",
    defaultMessage: "500",
  },
  blkioWeightTitle: {
    id: "forms.fieldExplanation.blkioWeight.title",
    defaultMessage: "Block I/O Weight",
  },
  blkioWeightDescription: {
    id: "forms.fieldExplanation.blkioWeight.description",
    defaultMessage:
      "Block I/O weight (relative weight) for the container. Range: 0 to 1000.",
  },
  blkioWeightExample: {
    id: "forms.fieldExplanation.blkioWeight.example",
    defaultMessage: "300",
  },
  blkioWeightDeviceTitle: {
    id: "forms.fieldExplanation.blkioWeightDevice.title",
    defaultMessage: "Block I/O Weight Device",
  },
  blkioWeightDeviceDescription: {
    id: "forms.fieldExplanation.blkioWeightDevice.description",
    defaultMessage:
      "Per-device block I/O weight. Each entry maps a device path to a weight.",
  },
  blkioWeightDeviceExample: {
    id: "forms.fieldExplanation.blkioWeightDevice.example",
    defaultMessage: "/dev/sda:500",
  },
  blkioDeviceReadBpsTitle: {
    id: "forms.fieldExplanation.blkioDeviceReadBps.title",
    defaultMessage: "Device Read Bps",
  },
  blkioDeviceReadBpsDescription: {
    id: "forms.fieldExplanation.blkioDeviceReadBps.description",
    defaultMessage: "Per-device read rate limit in bytes per second.",
  },
  blkioDeviceReadBpsExample: {
    id: "forms.fieldExplanation.blkioDeviceReadBps.example",
    defaultMessage: "10485760 (10 MB/s on /dev/sda)",
  },
  blkioDeviceWriteBpsTitle: {
    id: "forms.fieldExplanation.blkioDeviceWriteBps.title",
    defaultMessage: "Device Write Bps",
  },
  blkioDeviceWriteBpsDescription: {
    id: "forms.fieldExplanation.blkioDeviceWriteBps.description",
    defaultMessage: "Per-device write rate limit in bytes per second.",
  },
  blkioDeviceWriteBpsExample: {
    id: "forms.fieldExplanation.blkioDeviceWriteBps.example",
    defaultMessage: "5242880 (5 MB/s on /dev/sda)",
  },
  blkioDeviceReadIopsTitle: {
    id: "forms.fieldExplanation.blkioDeviceReadIops.title",
    defaultMessage: "Device Read IOPS",
  },
  blkioDeviceReadIopsDescription: {
    id: "forms.fieldExplanation.blkioDeviceReadIops.description",
    defaultMessage: "Per-device read rate limit in I/O operations per second.",
  },
  blkioDeviceReadIopsExample: {
    id: "forms.fieldExplanation.blkioDeviceReadIops.example",
    defaultMessage: "1000",
  },
  blkioDeviceWriteIopsTitle: {
    id: "forms.fieldExplanation.blkioDeviceWriteIops.title",
    defaultMessage: "Device Write IOPS",
  },
  blkioDeviceWriteIopsDescription: {
    id: "forms.fieldExplanation.blkioDeviceWriteIops.description",
    defaultMessage: "Per-device write rate limit in I/O operations per second.",
  },
  blkioDeviceWriteIopsExample: {
    id: "forms.fieldExplanation.blkioDeviceWriteIops.example",
    defaultMessage: "1000",
  },
  ulimitsTitle: {
    id: "forms.fieldExplanation.ulimits.title",
    defaultMessage: "Ulimits",
  },
  ulimitsDescription: {
    id: "forms.fieldExplanation.ulimits.description",
    defaultMessage: "Override container ulimit options (e.g. nofile, nproc).",
  },
  ulimitsExample: {
    id: "forms.fieldExplanation.ulimits.example",
    defaultMessage: "nofile soft=1024 hard=65536",
  },
  cgroupsModeTitle: {
    id: "forms.fieldExplanation.cgroupsMode.title",
    defaultMessage: "Cgroups Mode",
  },
  cgroupsModeDescription: {
    id: "forms.fieldExplanation.cgroupsMode.description",
    defaultMessage:
      "Cgroup namespace mode: host (use host cgroup namespace) or private (use a new cgroup namespace).",
  },
  cgroupsModeExample: {
    id: "forms.fieldExplanation.cgroupsMode.example",
    defaultMessage: "private",
  },
  ipcModeTitle: {
    id: "forms.fieldExplanation.ipcMode.title",
    defaultMessage: "IPC Mode",
  },
  ipcModeDescription: {
    id: "forms.fieldExplanation.ipcMode.description",
    defaultMessage: "IPC namespace mode to use for the container.",
  },
  ipcModeExample: {
    id: "forms.fieldExplanation.ipcMode.example",
    defaultMessage: "host",
  },
  usernsModeTitle: {
    id: "forms.fieldExplanation.usernsMode.title",
    defaultMessage: "User Namespace Mode",
  },
  usernsModeDescription: {
    id: "forms.fieldExplanation.usernsMode.description",
    defaultMessage: "User namespace mode for the container.",
  },
  usernsModeExample: {
    id: "forms.fieldExplanation.usernsMode.example",
    defaultMessage: "host",
  },
  pidModeTitle: {
    id: "forms.fieldExplanation.pidMode.title",
    defaultMessage: "PID Mode",
  },
  pidModeDescription: {
    id: "forms.fieldExplanation.pidMode.description",
    defaultMessage: "PID namespace mode: host or container:'<name|id>'.",
  },
  pidModeExample: {
    id: "forms.fieldExplanation.pidMode.example",
    defaultMessage: "host",
  },
  securityoptTitle: {
    id: "forms.fieldExplanation.securityopt.title",
    defaultMessage: "Security Options",
  },
  securityoptDescription: {
    id: "forms.fieldExplanation.securityopt.description",
    defaultMessage: "Security options for the container (e.g. SELinux labels).",
  },
  securityoptExample: {
    id: "forms.fieldExplanation.securityopt.example",
    defaultMessage: "label:level:s0:c100,c200",
  },
  maskedPathsTitle: {
    id: "forms.fieldExplanation.maskedPaths.title",
    defaultMessage: "Masked Paths",
  },
  maskedPathsDescription: {
    id: "forms.fieldExplanation.maskedPaths.description",
    defaultMessage:
      "Paths inside the container to mask, making them inaccessible.",
  },
  maskedPathsExample: {
    id: "forms.fieldExplanation.maskedPaths.example",
    defaultMessage: "/proc/kcore",
  },
  readonlyPathsTitle: {
    id: "forms.fieldExplanation.readonlyPaths.title",
    defaultMessage: "Read-only Paths",
  },
  readonlyPathsDescription: {
    id: "forms.fieldExplanation.readonlyPaths.description",
    defaultMessage: "Paths inside the container to make read-only.",
  },
  readonlyPathsExample: {
    id: "forms.fieldExplanation.readonlyPaths.example",
    defaultMessage: "/proc/bus/usb",
  },
  groupAddTitle: {
    id: "forms.fieldExplanation.groupAdd.title",
    defaultMessage: "Group Add",
  },
  groupAddDescription: {
    id: "forms.fieldExplanation.groupAdd.description",
    defaultMessage: "Additional groups the container process should belong to.",
  },
  groupAddExample: {
    id: "forms.fieldExplanation.groupAdd.example",
    defaultMessage: "staff",
  },
  deviceCgroupRulesTitle: {
    id: "forms.fieldExplanation.deviceCgroupRules.title",
    defaultMessage: "Device Cgroup Rules",
  },
  deviceCgroupRulesDescription: {
    id: "forms.fieldExplanation.deviceCgroupRules.description",
    defaultMessage: "Device cgroup rules for the container (e.g. a *:* rwm).",
  },
  deviceCgroupRulesExample: {
    id: "forms.fieldExplanation.deviceCgroupRules.example",
    defaultMessage: "a *:* rwm",
  },
  runtimeTitle: {
    id: "forms.fieldExplanation.runtime.title",
    defaultMessage: "Runtime",
  },
  runtimeDescription: {
    id: "forms.fieldExplanation.runtime.description",
    defaultMessage: "OCI runtime to use for the container.",
  },
  runtimeExample: {
    id: "forms.fieldExplanation.runtime.example",
    defaultMessage: "nvidia",
  },
  stopSignalTitle: {
    id: "forms.fieldExplanation.stopSignal.title",
    defaultMessage: "Stop Signal",
  },
  stopSignalDescription: {
    id: "forms.fieldExplanation.stopSignal.description",
    defaultMessage: "Signal to send to the container to stop it.",
  },
  stopSignalExample: {
    id: "forms.fieldExplanation.stopSignal.example",
    defaultMessage: "SIGTERM",
  },
  stopTimeoutTitle: {
    id: "forms.fieldExplanation.stopTimeout.title",
    defaultMessage: "Stop Timeout",
  },
  stopTimeoutDescription: {
    id: "forms.fieldExplanation.stopTimeout.description",
    defaultMessage:
      "Timeout in seconds to wait for the container to stop gracefully.",
  },
  stopTimeoutExample: {
    id: "forms.fieldExplanation.stopTimeout.example",
    defaultMessage: "30",
  },
  labelsTitle: {
    id: "forms.fieldExplanation.labels.title",
    defaultMessage: "Labels",
  },
  labelsDescription: {
    id: "forms.fieldExplanation.labels.description",
    defaultMessage: "Key-value metadata labels for the container.",
  },
  labelsExample: {
    id: "forms.fieldExplanation.labels.example",
    defaultMessage: "env=production",
  },
  sysctlsTitle: {
    id: "forms.fieldExplanation.sysctls.title",
    defaultMessage: "Sysctls",
  },
  sysctlsDescription: {
    id: "forms.fieldExplanation.sysctls.description",
    defaultMessage: "Kernel parameters (sysctls) to set in the container.",
  },
  sysctlsExample: {
    id: "forms.fieldExplanation.sysctls.example",
    defaultMessage: "net.core.somaxconn=1024",
  },
  logTypeTitle: {
    id: "forms.fieldExplanation.logType.title",
    defaultMessage: "Log Type",
  },
  logTypeDescription: {
    id: "forms.fieldExplanation.logType.description",
    defaultMessage: "Logging driver name (e.g. json-file, syslog) or none.",
  },
  logTypeExample: {
    id: "forms.fieldExplanation.logType.example",
    defaultMessage: "json-file",
  },
  logConfigTitle: {
    id: "forms.fieldExplanation.logConfig.title",
    defaultMessage: "Log Config",
  },
  logConfigDescription: {
    id: "forms.fieldExplanation.logConfig.description",
    defaultMessage: "Configuration options for the logging driver.",
  },
  logConfigExample: {
    id: "forms.fieldExplanation.logConfig.example",
    defaultMessage: "max-size=10m",
  },
});

export { fieldExplanations };
