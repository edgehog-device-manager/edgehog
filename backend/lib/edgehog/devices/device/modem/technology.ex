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

defmodule Edgehog.Devices.Device.Modem.Technology do
  use Ash.Type.Enum,
    values: [
      gsm: "GSM.",
      gsm_compact: "GSM Compact.",
      utran: "UTRAN.",
      gsm_egprs: "GSM with EGPRS.",
      utran_hsdpa: "UTRAN with HSDPA.",
      utran_hsupa: "UTRAN with HSUPA.",
      utran_hsdpa_hsupa: "UTRAN with HSDPA and HSUPA.",
      eutran: "E-UTRAN."
    ]

  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_type(_), do: :modem_technology

  def match("GSM"), do: {:ok, :gsm}
  def match("GSMCompact"), do: {:ok, :gsm_compact}
  def match("UTRAN"), do: {:ok, :utran}
  def match("GSMwEGPRS"), do: {:ok, :gsm_egprs}
  def match("UTRANwHSDPA"), do: {:ok, :utran_hsdpa}
  def match("UTRANwHSUPA"), do: {:ok, :utran_hsupa}
  def match("UTRANwHSDPAandHSUPA"), do: {:ok, :utran_hsdpa_hsupa}
  def match("EUTRAN"), do: {:ok, :eutran}
  def match(term), do: super(term)
end
