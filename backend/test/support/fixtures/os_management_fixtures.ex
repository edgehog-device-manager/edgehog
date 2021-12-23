#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.OSManagementFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.OSManagement` context.
  """

  @doc """
  Generate a ota_operation.
  """
  def ota_operation_fixture(attrs \\ %{}) do
    {:ok, ota_operation} =
      attrs
      |> Enum.into(%{
        image_url: "some image_url",
        status: "some status",
        status_code: "some status_code"
      })
      |> Edgehog.OSManagement.create_ota_operation()

    ota_operation
  end
end
