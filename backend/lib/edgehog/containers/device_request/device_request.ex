#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Containers.DeviceRequest do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Validations

  graphql do
    type :device_request
  end

  actions do
    defaults [
      :read,
      :update,
      :destroy
    ]

    create :create do
      primary? true

      accept [:driver, :count, :device_ids, :options]

      argument :capabilities, {:array, {:array, :string}} do
        description """
        A list of capabilities; an OR list of AND lists of capabilities.

        Note that if a driver is specified, the capabilities have no effect
        on selecting a driver, as the driver name is used directly.

        If no driver is specified, the capabilities are used to select a
        driver with the required capabilities.
        """
      end

      change fn changeset, _context ->
        capabilities =
          changeset
          |> Ash.Changeset.get_argument(:capabilities)
          |> Kernel.||([])
          |> Enum.map(&Jason.encode!/1)

        Ash.Changeset.change_attribute(
          changeset,
          :db_capabilities,
          capabilities
        )
      end
    end

    destroy :destroy_if_dangling do
      description "Destroys the device request if it's dangling (not referenced by any container)"

      require_atomic? false
      validate Validations.Dangling
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :driver, :string do
      description """
      The name of the device driver to use for this request.
      Note that if this is specified, the capabilities are ignored
      when selecting a device driver. Default value is an empty string.
      """

      public? true

      default ""
    end

    attribute :count, :integer do
      description """
      Count for the device to request for the container.
      Default value is -1.
      """

      public? true

      default -1
    end

    attribute :device_ids, {:array, :string} do
      description """
      IDs of the devices to request for the container.
      """

      public? true

      default []
    end

    attribute :db_capabilities, {:array, :string} do
      description """
      Internal database representation of device capabilities.

      Each capability group is stored as a JSON-encoded string to support
      PostgreSQL storage and querying. Use the `capabilities` calculation
      to access the decoded list of capability groups.
      """

      default []
    end

    attribute :options, :map do
      description """
      Driver-specific options, specified as key/value pairs.
      These options are passed directly to the driver.
      """

      public? true

      default %{}
    end
  end

  relationships do
    belongs_to :container, Container do
      source_attribute :container_id
      attribute_type :uuid
      public? true
    end
  end

  calculations do
    calculate :capabilities,
              {:array, {:array, :string}} do
      description """
      A list of capabilities; an OR list of AND lists of capabilities.

      Note that if a driver is specified, the capabilities have no effect
      on selecting a driver, as the driver name is used directly.

      If no driver is specified, the capabilities are used to select a
      driver with the required capabilities.
      """

      public? true

      calculation Edgehog.Containers.DeviceRequest.Calculations.Capabilities
    end

    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :containers]}
  end

  postgres do
    table "device_requests"
    repo Edgehog.Repo
  end
end
