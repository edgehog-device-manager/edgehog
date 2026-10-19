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

defmodule Edgehog.Forwarder.Guardian do
  @moduledoc """
  Auth layer to handle connections to the device forwarder.
  """
  use Guardian, otp_app: :edgehog

  def subject_for_token(_resource, _claims), do: {:ok, "edgehog_forwarder_sessions"}
  def resource_from_claims(claims), do: {:ok, claims}
end
