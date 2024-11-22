#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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
alias Edgehog.Containers.Container
alias Edgehog.Containers.ContainerNetwork
alias Edgehog.Containers.Release.Deployment
alias Edgehog.Containers.Image
alias Edgehog.Containers.ImageCredentials
alias Edgehog.Containers.Network
alias Edgehog.Containers.Release
alias Edgehog.Containers.ReleaseContainers
alias Edgehog.Devices.Device
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

if status == :default do
  """
  You are using the default realm private key. \
  This instance will not be able to connect to Astarte.
  """
  |> String.trim_trailing("\n")
  |> Logger.warning()
end

realm =
  Astarte.create_realm!(
    %{cluster_id: cluster.id, name: read_env_var.("SEEDS_REALM"), private_key: realm_pk},
    tenant: tenant
  )

# Feature Application Management

app_without_releases =
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

app_nginx_8080 =
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

app_nginx_8081 =
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

image_credentials =
  Ash.create!(
    ImageCredentials,
    %{label: "Credentials", username: "username", password: "password"},
    tenant: tenant
  )

app_with_credentials =
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
