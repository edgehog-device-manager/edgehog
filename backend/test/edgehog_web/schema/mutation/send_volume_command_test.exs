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

defmodule EdgehogWeb.Schema.Mutation.SendVolumeCommandTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Astarte.Device.VolumeCommand
  alias Edgehog.Astarte.Device.VolumeCommand.RequestData

  setup %{tenant: tenant} do
    volume = volume_fixture(tenant: tenant)
    device = device_fixture(tenant: tenant)
    volume_deployment_fixture(tenant: tenant, volume_id: volume.id, device_id: device.id)
    %{volume: volume, device: device}
  end

  test "sends the command to the selected device", %{
    tenant: tenant,
    volume: volume,
    device: device
  } do
    other_device = device_fixture(tenant: tenant)
    volume_deployment_fixture(tenant: tenant, volume_id: volume.id, device_id: other_device.id)
    device_id = device.device_id
    volume_id = volume.id

    expect(VolumeCommand, :send_volume_command, fn _,
                                                   ^device_id,
                                                   %RequestData{
                                                     volume_id: ^volume_id,
                                                     command: "Delete"
                                                   } ->
      :ok
    end)

    assert %{data: %{"sendVolumeCommand" => %{"result" => %{"id" => id}}}} =
             mutation(tenant, volume, device)

    assert id == AshGraphql.Resource.encode_relay_id(volume)
  end

  test "rejects a device without the volume deployment", %{tenant: tenant, volume: volume} do
    other_device = device_fixture(tenant: tenant)
    reject(&VolumeCommand.send_volume_command/3)

    assert %{errors: [_ | _]} = mutation(tenant, volume, other_device)
  end

  test "rejects a missing device", %{tenant: tenant, volume: volume, device: device} do
    reject(&VolumeCommand.send_volume_command/3)
    missing_device = %{device | id: Ash.UUID.generate()}

    assert %{errors: [_ | _]} = mutation(tenant, volume, missing_device)
  end

  test "rejects a device from another tenant", %{tenant: tenant, volume: volume} do
    other_tenant = Edgehog.TenantsFixtures.tenant_fixture()
    other_device = device_fixture(tenant: other_tenant)
    reject(&VolumeCommand.send_volume_command/3)

    assert %{errors: [_ | _]} = mutation(tenant, volume, other_device)
  end

  test "rejects a volume ID passed as a device ID", %{tenant: tenant, volume: volume} do
    reject(&VolumeCommand.send_volume_command/3)

    assert %{errors: [_ | _]} = mutation(tenant, volume, volume)
  end

  test "rejects a missing volume", %{tenant: tenant, volume: volume, device: device} do
    reject(&VolumeCommand.send_volume_command/3)
    missing_volume = %{volume | id: Ash.UUID.generate()}

    assert %{errors: [_ | _]} = mutation(tenant, missing_volume, device)
  end

  test "rejects an invalid or missing command", %{tenant: tenant, volume: volume, device: device} do
    reject(&VolumeCommand.send_volume_command/3)

    assert %{errors: [_ | _]} = mutation(tenant, volume, device, "INVALID")
    assert %{errors: [_ | _]} = mutation(tenant, volume, device, nil)
  end

  test "reports a failure from Astarte", %{tenant: tenant, volume: volume, device: device} do
    expect(VolumeCommand, :send_volume_command, fn _, _, _ ->
      {:error, %RuntimeError{message: "Astarte unavailable"}}
    end)

    assert %{errors: [_ | _]} = mutation(tenant, volume, device)
  end

  defp mutation(tenant, volume, device, command \\ "DELETE") do
    document = """
    mutation SendVolumeCommand($volumeId: ID!, $deviceId: ID!, $command: VolumeCommand!) {
      sendVolumeCommand(id: $volumeId, deviceId: $deviceId, command: $command) {
        result { id }
      }
    }
    """

    variables = %{
      "volumeId" => AshGraphql.Resource.encode_relay_id(volume),
      "deviceId" => AshGraphql.Resource.encode_relay_id(device),
      "command" => command
    }

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end
end
