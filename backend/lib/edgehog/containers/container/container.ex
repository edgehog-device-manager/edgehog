#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Container do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Container.EnvEncoding
  alias Edgehog.Containers.Container.ManualActions
  alias Edgehog.Containers.Container.Validations.CpuPeriodQuotaConsistency
  alias Edgehog.Containers.Container.Validations.VolumeTargetUniqueness
  alias Edgehog.Containers.ContainerVolume
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Types.RestartPolicy

  graphql do
    type :container

    paginate_relationship_with networks: :relay,
                               devices: :relay,
                               volumes: :relay,
                               releases: :relay,
                               container_volumes: :relay,
                               device_mappings: :relay
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :port_bindings,
        :restart_policy,
        :hostname,
        :network_mode,
        :env,
        :privileged,
        :extra_hosts,
        :image_id,
        :cap_add,
        :cap_drop,
        :cpu_period,
        :cpu_quota,
        :cpu_realtime_period,
        :cpu_realtime_runtime,
        :memory,
        :memory_reservation,
        :memory_swap,
        :memory_swappiness,
        :volume_driver,
        :storage_opt,
        :read_only_rootfs,
        :tmpfs,
        :image_id
      ],
      update: [
        :port_bindings,
        :restart_policy,
        :hostname,
        :network_mode,
        :env,
        :privileged,
        :extra_hosts,
        :image_id,
        :cap_add,
        :cap_drop,
        :cpu_period,
        :cpu_quota,
        :cpu_realtime_period,
        :cpu_realtime_runtime,
        :memory,
        :memory_reservation,
        :memory_swap,
        :memory_swappiness,
        :volume_driver,
        :storage_opt,
        :read_only_rootfs,
        :tmpfs,
        :image_id
      ]
    ]

    create :create_with_nested do
      accept [
        :restart_policy,
        :hostname,
        :env,
        :privileged,
        :port_bindings,
        :network_mode,
        :extra_hosts,
        :cap_add,
        :cap_drop,
        :cpu_period,
        :cpu_quota,
        :cpu_realtime_period,
        :cpu_realtime_runtime,
        :memory,
        :memory_reservation,
        :memory_swap,
        :memory_swappiness,
        :volume_driver,
        :storage_opt,
        :read_only_rootfs,
        :tmpfs
      ]

      argument :image, :map
      argument :networks, {:array, :map}
      argument :volumes, {:array, :map}
      argument :device_mappings, {:array, :map}

      change manage_relationship(:volumes,
               on_no_match: :error,
               on_lookup: {:relate_and_update, :create, :read, [:target]}
             )

      change manage_relationship(:image,
               on_no_match: :create,
               on_lookup: :relate,
               on_match: :ignore,
               use_identities: [:reference]
             )

      change manage_relationship(:networks,
               on_no_match: :error,
               on_lookup: :relate
             )

      change manage_relationship(:device_mappings,
               type: :create
             )
    end

    create :create_fixture do
      accept [
        :port_bindings,
        :restart_policy,
        :hostname,
        :network_mode,
        :env,
        :privileged,
        :image_id,
        :extra_hosts,
        :cap_add,
        :cap_drop,
        :cpu_period,
        :cpu_quota,
        :cpu_realtime_period,
        :cpu_realtime_runtime,
        :memory,
        :memory_reservation,
        :memory_swap,
        :memory_swappiness,
        :volume_driver,
        :storage_opt,
        :read_only_rootfs,
        :tmpfs,
        :image_id
      ]

      argument :volumes, {:array, :map}
      argument :networks, {:array, :uuid}
      argument :device_mappings, {:array, :uuid}

      change manage_relationship(:volumes,
               on_no_match: {:create, :create, :create, [:target]},
               on_lookup: {:relate, :create}
             )

      change manage_relationship(:networks, type: :append)
      change manage_relationship(:device_mappings, type: :append)
    end

    read :filter_by_image do
      argument :image_id, :uuid

      filter expr(image_id == ^arg(:image_id))
    end

    destroy :destroy_if_dangling do
      description "Destroys the container if it's dangling (not referenced by any release)"

      manual ManualActions.DestroyIfDangling
    end
  end

  validations do
    validate CpuPeriodQuotaConsistency
    validate VolumeTargetUniqueness
  end

  attributes do
    uuid_primary_key :id

    attribute :restart_policy, RestartPolicy do
      public? true
    end

    attribute :port_bindings, {:array, :string} do
      default []
      allow_nil? false
      public? true
    end

    attribute :hostname, :string do
      constraints allow_empty?: true
      default ""
      allow_nil? false
      public? true
    end

    attribute :env, :map do
      default %{}
      public? true
    end

    attribute :privileged, :boolean do
      default false
      public? true
    end

    attribute :network_mode, :string do
      default "bridge"
      public? true
      allow_nil? false
    end

    attribute :extra_hosts, {:array, :string} do
      default []
      allow_nil? false
      public? true
    end

    attribute :cap_add, {:array, :string} do
      default []
      allow_nil? false
      public? true
    end

    attribute :cap_drop, {:array, :string} do
      default []
      allow_nil? false
      public? true
    end

    attribute :cpu_period, :integer do
      public? true
      constraints min: 1_000, max: 1_000_000
    end

    attribute :cpu_quota, :integer do
      public? true
      constraints min: 1_000
    end

    attribute :cpu_realtime_period, :integer do
      public? true
    end

    attribute :cpu_realtime_runtime, :integer do
      public? true
    end

    attribute :memory, :integer do
      public? true
    end

    attribute :memory_reservation, :integer do
      public? true
    end

    attribute :memory_swap, :integer do
      public? true
    end

    attribute :memory_swappiness, :integer do
      public? true
    end

    attribute :volume_driver, :string do
      default ""
      public? true
      allow_nil? false
      constraints allow_empty?: true
    end

    attribute :storage_opt, {:array, :string} do
      default []
      public? true
      allow_nil? false
    end

    attribute :read_only_rootfs, :boolean do
      default false
      public? true
      allow_nil? false
    end

    attribute :tmpfs, {:array, :string} do
      default []
      public? true
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :image, Image do
      source_attribute :image_id
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    many_to_many :releases, Edgehog.Containers.Release do
      through Edgehog.Containers.ReleaseContainers
      public? true
    end

    many_to_many :volumes, Edgehog.Containers.Volume do
      through ContainerVolume
      join_relationship :container_volumes
    end

    many_to_many :networks, Edgehog.Containers.Network do
      through Edgehog.Containers.ContainerNetwork
      public? true
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.Container.Deployment
      join_relationship :container_deployments
      public? true
    end

    has_many :container_volumes, ContainerVolume do
      public? true
    end

    has_many :device_mappings, Edgehog.Containers.DeviceMapping do
      public? true
    end
  end

  calculations do
    calculate :env_encoding, :vector, EnvEncoding

    calculate :dangling?, :boolean, Edgehog.Containers.Container.Calculations.Dangling do
      description "Returns true if this container has no releases referring to it"
    end
  end

  postgres do
    table "containers"
  end
end
