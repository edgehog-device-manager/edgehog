#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule EdgehogWeb.AdminAPI.Auth.Pipeline do
  @moduledoc false
  use Plug.Builder

  plug Guardian.Plug.Pipeline,
    otp_app: :edgehog,
    module: EdgehogWeb.AdminAPI.Auth.Token,
    error_handler: EdgehogWeb.AdminAPI.Auth.ErrorHandler

  plug Guardian.Plug.VerifyHeader, claims: %{e_ara: "*"}
  plug Guardian.Plug.EnsureAuthenticated
end
