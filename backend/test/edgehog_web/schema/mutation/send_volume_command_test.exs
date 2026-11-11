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

    volume_deployment =
      volume_deployment_fixture(tenant: tenant, volume_id: volume.id, device_id: device.id)

    %{volume: volume, device: device, volume_deployment: volume_deployment}
  end

  test "sends the command to the selected device", %{
    tenant: tenant,
    volume: volume,
    device: device,
    volume_deployment: volume_deployment
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
             mutation(tenant, volume_deployment)

    assert id == AshGraphql.Resource.encode_relay_id(volume_deployment)
  end

  test "rejects a missing volume deployment", %{
    tenant: tenant,
    volume_deployment: volume_deployment
  } do
    reject(&VolumeCommand.send_volume_command/3)
    missing_deployment = %{volume_deployment | id: Ash.UUID.generate()}

    assert %{errors: [_ | _]} = mutation(tenant, missing_deployment)
  end

  test "rejects a volume deployment from another tenant", %{tenant: tenant} do
    other_tenant = Edgehog.TenantsFixtures.tenant_fixture()
    other_deployment = volume_deployment_fixture(tenant: other_tenant)
    reject(&VolumeCommand.send_volume_command/3)

    assert %{errors: [_ | _]} = mutation(tenant, other_deployment)
  end

  test "rejects an invalid or missing command", %{
    tenant: tenant,
    volume_deployment: volume_deployment
  } do
    reject(&VolumeCommand.send_volume_command/3)

    assert %{errors: [_ | _]} = mutation(tenant, volume_deployment, "INVALID")
    assert %{errors: [_ | _]} = mutation(tenant, volume_deployment, nil)
  end

  test "reports a failure from Astarte", %{tenant: tenant, volume_deployment: volume_deployment} do
    expect(VolumeCommand, :send_volume_command, fn _, _, _ ->
      {:error, %RuntimeError{message: "Astarte unavailable"}}
    end)

    assert %{errors: [_ | _]} = mutation(tenant, volume_deployment)
  end

  defp mutation(tenant, volume_deployment, command \\ "DELETE") do
    document = """
    mutation SendVolumeCommand($id: ID!, $command: VolumeCommand!) {
      sendVolumeCommand(id: $id, command: $command) {
        result { id }
      }
    }
    """

    variables = %{
      "id" => AshGraphql.Resource.encode_relay_id(volume_deployment),
      "command" => command
    }

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end
end
