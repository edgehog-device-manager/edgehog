#
# This file is part of Edgehog.
#
# Copyright 2021-2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

alias Edgehog.Astarte
alias Edgehog.Containers.Application
alias Edgehog.Containers.Deployment
alias Edgehog.Containers.ImageCredentials
alias Edgehog.Containers.Network
alias Edgehog.Containers.Release
alias Edgehog.Containers.Volume
alias Edgehog.Devices.Device
alias Edgehog.Devices.HardwareType
alias Edgehog.Devices.SystemModel
alias Edgehog.Tenants

require Logger

default_var =
  if File.exists?("../.env") do
    defaults = Envar.read("../.env")

    fn var ->
      # paths in the .env are relative to ../
      defaults
      |> Map.fetch!(var)
      |> String.replace_prefix("../", "../../")
      |> String.replace_prefix("./", "../")
    end
  else
    fn _var -> nil end
  end

# gives priority to system env vars
read_env_var = fn var ->
  default = default_var.(var)
  System.get_env(var, default)
end

file_names_from_env_vars = fn file_name_var, original_file_name_var ->
  file_name = read_env_var.(file_name_var)
  original_file_name = System.get_env(original_file_name_var, file_name)
  {file_name, original_file_name}
end

# original_file_name_var is used in docker to keep a reference to the original file.
read_file_from_env_var! = fn file_var, original_file_name_var ->
  {file_name, original_file_name} = file_names_from_env_vars.(file_var, original_file_name_var)

  file_name
  |> File.read()
  |> case do
    {:ok, content} ->
      content

    {:error, reason} ->
      raise ~s[#{file_var} (set to "#{original_file_name}"): #{:file.format_error(reason)}]
  end
end

read_key! = fn key_file_var, original_key_file_var, default_key_file_name ->
  {_, original_file_name} =
    file_names_from_env_vars.(key_file_var, original_key_file_var)

  key_content = read_file_from_env_var!.(key_file_var, original_key_file_var)

  # from_pem! + to_pem is used to remove indentation and comments
  default_key =
    :edgehog
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("repo/seeds/keys/#{default_key_file_name}.pem")
    |> File.read!()
    |> X509.PrivateKey.from_pem!()
    |> X509.PrivateKey.to_pem()

  key =
    case X509.PrivateKey.from_pem(key_content) do
      {:ok, pk_binary} ->
        X509.PrivateKey.to_pem(pk_binary)

      {:error, _} ->
        raise ~s[#{key_file_var} (set to "#{original_file_name}"): not a valid private key]
    end

  status =
    case key do
      ^default_key -> :default
      _ -> :ok
    end

  {status, key}
end

cluster =
  Astarte.create_cluster!(%{
    name: "Test Cluster",
    base_api_url: read_env_var.("SEEDS_ASTARTE_BASE_API_URL")
  })

{status, private_key} =
  read_key!.("SEEDS_TENANT_PRIVATE_KEY_FILE", "SEEDS_TENANT_ORIGINAL_FILE", "tenant_private")

if status == :default do
  """
  Using default tenant private key. \
  Please be sure to avoid using this for production.
  """
  |> String.trim_trailing("\n")
  |> Logger.warning()
end

public_key =
  private_key
  |> X509.PrivateKey.from_pem!()
  |> X509.PublicKey.derive()
  |> X509.PublicKey.to_pem()

tenant =
  Tenants.create_tenant!(%{name: "ACME Inc", slug: "acme-inc", public_key: public_key})

{status, realm_pk} =
  read_key!.("SEEDS_REALM_PRIVATE_KEY_FILE", "SEEDS_REALM_ORIGINAL_FILE", "realm_private")

realm =
  Astarte.create_realm!(
    %{cluster_id: cluster.id, name: read_env_var.("SEEDS_REALM"), private_key: realm_pk},
    tenant: tenant
  )

if status == :default do
  """
  You are using the default realm private key. \
  This instance will not be able to connect to Astarte.
  """
  |> String.trim_trailing("\n")
  |> Logger.warning()
else
  Tenants.reconcile_tenant(tenant)
end

# Feature Application Management

_app_without_releases =
  Ash.create!(
    Application,
    %{
      name: "App without releases",
      description:
        "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
    },
    tenant: tenant
  )

app_with_multiple_releases =
  Ash.create!(
    Application,
    %{
      name: "App with multiple releases",
      description:
        "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
      initial_release: %{
        version: "1.0.0",
        containers: []
      }
    },
    tenant: tenant
  )

Ash.create!(
  Release,
  %{
    application_id: app_with_multiple_releases.id,
    version: "1.0.1",
    containers: []
  },
  tenant: tenant
)

app_nginx =
  Ash.create!(
    Application,
    %{
      name: "Nginx",
      description:
        "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            restart_policy: :unless_stopped,
            hostname: "",
            env: %{},
            privileged: false,
            network_mode: "bridge",
            port_bindings: []
          }
        ]
      }
    },
    tenant: tenant
  )

_app_nginx_8080 =
  Ash.create!(
    Application,
    %{
      name: "Nginx bound on port 8080",
      description:
        "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            restart_policy: :unless_stopped,
            hostname: "",
            env: %{},
            privileged: false,
            network_mode: "bridge",
            port_bindings: ["8080:80"]
          }
        ]
      }
    },
    tenant: tenant
  )

_app_nginx_8081 =
  Ash.create!(
    Application,
    %{
      name: "Nginx bound on port 8081",
      description:
        "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            restart_policy: :unless_stopped,
            hostname: "",
            env: %{},
            privileged: false,
            network_mode: "bridge",
            port_bindings: ["8081:80"]
          }
        ]
      }
    },
    tenant: tenant
  )

self_hosted_credentials =
  Ash.create!(
    ImageCredentials,
    %{label: "Self-hosted registry credentials", username: "admin", password: "admin"},
    tenant: tenant
  )

_app_test_dev_self_hosted =
  Ash.create!(
    Application,
    %{
      name: "Self-hosted app",
      description: "It was sample for self-hosted deployments.",
      initial_release: %{
        version: "0.0.1",
        containers: [
          %{
            image: %{
              reference: "registry.edgehog.localhost/test/http-echo:latest",
              image_credentials_id: self_hosted_credentials.id
            },
            restart_policy: :unless_stopped,
            hostname: "",
            env: %{},
            privileged: false,
            port_bindings: ["5678:5678"]
          }
        ]
      }
    },
    tenant: tenant
  )

image_credentials =
  Ash.create!(
    ImageCredentials,
    %{label: "Credentials", username: "username", password: "password"},
    tenant: tenant
  )

_app_with_credentials =
  Ash.create!(
    Application,
    %{
      name: "App with credentials",
      description:
        "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "httpd:latest", image_credentials_id: image_credentials.id},
            restart_policy: :unless_stopped,
            hostname: "",
            env: %{},
            privileged: false,
            network_mode: "bridge",
            port_bindings: []
          }
        ]
      }
    },
    tenant: tenant
  )

_app_with_capabilities =
  Ash.create!(
    Application,
    %{
      name: "App with Linux Capabilities",
      description: "Demonstrates capability add/drop settings.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            cap_add: ["CAP_SYS_ADMIN", "CAP_NET_ADMIN"],
            cap_drop: ["CAP_CHOWN"]
          }
        ]
      }
    },
    tenant: tenant
  )

_app_with_cpu_limits =
  Ash.create!(
    Application,
    %{
      name: "App with CPU Limits",
      description: "Demonstrates containers with CPU quota and period settings.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            cpu_period: 100_000,
            cpu_quota: 200_000,
            cpu_realtime_period: 1500,
            cpu_realtime_runtime: 1000
          }
        ]
      }
    },
    tenant: tenant
  )

_app_with_device_mappings =
  Ash.create!(
    Application,
    %{
      name: "App with Device Mappings",
      description: "Demonstrates mapping of host devices into containers.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            device_mappings: [
              %{
                path_on_host: "/dev/zero",
                path_in_container: "/dev/myzero",
                cgroup_permissions: "mrw"
              }
            ]
          }
        ]
      }
    },
    tenant: tenant
  )

hardware_type =
  Ash.create!(
    HardwareType,
    %{
      name: "test_hardware_type",
      handle: "test-hardware-type",
      part_numbers: ["HW001", "HW002"]
    },
    tenant: tenant
  )

system_model =
  Ash.create!(
    SystemModel,
    %{
      name: "test_system_model",
      handle: "test-system-model",
      hardware_type_id: hardware_type.id,
      part_numbers: ["SM001", "SM002"]
    },
    tenant: tenant
  )

_application_with_system_model =
  Ash.create!(
    Application,
    %{
      name: "App with System Model",
      description: "Application that specifies a required system model for deployment. \
This ensures the app can only be installed on compatible hardware configurations \
matching the associated system model, improving deployment reliability and hardware compatibility validation.",
      initial_release: %{
        version: "1.0.0",
        required_system_models: [%{id: system_model.id}]
      }
    },
    tenant: tenant
  )

volume1 =
  Ash.create!(
    Volume,
    %{
      label: "volume1",
      options: %{device: "tmpfs", o: "size=100m", type: "tmpfs"}
    },
    tenant: tenant
  )

volume2 =
  Ash.create!(
    Volume,
    %{
      label: "volume2"
    },
    tenant: tenant
  )

_app_with_volumes =
  Ash.create!(
    Application,
    %{
      name: "App with Volumes",
      description: "Application demonstrating how to attach multiple volumes to a single container. \
Each volume is mounted inside the container at a specific target path, allowing data persistence \
and shared storage between containers or across deployments.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            volumes: [
              %{
                id: volume1.id,
                target: "test/volume1"
              },
              %{
                id: volume2.id,
                target: "test/volume2"
              }
            ]
          }
        ]
      }
    },
    tenant: tenant
  )

network1 = Ash.create!(Network, %{label: "network1"}, tenant: tenant)

_app_with_networks =
  Ash.create!(
    Application,
    %{
      name: "App with Networks",
      description: "Application demonstrating how to connect a container to one or more user-defined networks. \
This setup allows fine-grained control over container communication, network isolation, and service discovery.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            networks: [%{id: network1.id}]
          }
        ]
      }
    },
    tenant: tenant
  )

_app_with_memory_limits =
  Ash.create!(
    Application,
    %{
      name: "App with Memory Limits",
      description: "Demonstrates memory and swap configuration options.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            memory: 512 * 1024 * 1024,
            memory_reservation: 256 * 1024 * 1024,
            memory_swap: 1024 * 1024 * 1024,
            memory_swappiness: 60
          }
        ]
      }
    },
    tenant: tenant
  )

_app_with_env_vars =
  Ash.create!(
    Application,
    %{
      name: "App with Environment Variables",
      description: "Demonstrates passing environment variables to containers.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "httpd:latest"},
            env: [%{key: "MODE", value: "production"}, %{key: "DEBUG", value: "false"}]
          }
        ]
      }
    },
    tenant: tenant
  )

_app_with_multiple_containers =
  Ash.create!(
    Application,
    %{
      name: "App with Multiple Containers",
      description: "An app that demonstrates multi-container composition.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            hostname: "frontend",
            port_bindings: ["8080:80"],
            restart_policy: :unless_stopped,
            privileged: false,
            network_mode: "bridge"
          },
          %{
            image: %{reference: "redis:7"},
            hostname: "cache",
            restart_policy: :always,
            privileged: false,
            network_mode: "bridge"
          }
        ]
      }
    },
    tenant: tenant
  )

_app_with_tmpfs =
  Ash.create!(
    Application,
    %{
      name: "App with Tmpfs Mount",
      description: "Container configured with tmpfs options.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            tmpfs: ["/tmp=rw,size=64m"]
          }
        ]
      }
    },
    tenant: tenant
  )

_app_with_readonly_rootfs =
  Ash.create!(
    Application,
    %{
      name: "App with Read-only Root Filesystem",
      description: "Demonstrates container with read-only root filesystem.",
      initial_release: %{
        version: "1.0.0",
        containers: [
          %{
            image: %{reference: "nginx:latest"},
            read_only_rootfs: true
          }
        ]
      }
    },
    tenant: tenant
  )

# Create a device (Note: This is just for demonstration purposes, as the Device is not actually connected to Astarte)
device =
  Ash.create!(
    Device,
    %{
      device_id: "9El7OzYqRVmLs0CGMB1J8g",
      name: "Test Device",
      online: false,
      realm_id: realm.id
    },
    tenant: tenant
  )

[app_nginx_release] = Ash.load!(app_nginx, :releases).releases

# Create a deployment for the device with an empty application
_deployment =
  Ash.create!(
    Deployment,
    %{
      device_id: device.id,
      release_id: app_nginx_release.id
    },
    tenant: tenant
  )

:ok
