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

defmodule Openfga.V1.ConsistencyPreference do
  @moduledoc """
  Controls the consistency preferences when calling the query APIs.
  """

  use Protobuf,
    enum: true,
    full_name: "openfga.v1.ConsistencyPreference",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :UNSPECIFIED, 0
  field :MINIMIZE_LATENCY, 100
  field :HIGHER_CONSISTENCY, 200
end
