#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Devices.Device.Modem.RegistrationStatus do
  use Ash.Type.Enum,
    values: [
      not_registered:
        "Not registered, modem is not currently searching a new operator to register to.",
      registered: "Registered, home network.",
      searching_operator:
        "Not registered, but modem is currently searching a new operator to register to.",
      registration_denied: "Registration denied.",
      unknown: "Unknown (e.g. out of GERAN/UTRAN/E-UTRAN coverage).",
      registered_roaming: "Registered, roaming."
    ]

  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_type(_), do: :modem_registration_status

  def match("NotRegistered"), do: {:ok, :not_registered}
  def match("Registered"), do: {:ok, :registered}
  def match("SearchingOperator"), do: {:ok, :searching_operator}
  def match("RegistrationDenied"), do: {:ok, :registration_denied}
  def match("Unknown"), do: {:ok, :unknown}
  def match("RegisteredRoaming"), do: {:ok, :registered_roaming}
  def match(term), do: super(term)
end
