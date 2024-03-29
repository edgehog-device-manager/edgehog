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

defmodule EdgehogWeb.AdminAPI.TenantsController do
  use EdgehogWeb, :controller

  alias Edgehog.Provisioning

  action_fallback EdgehogWeb.AdminAPI.FallbackController

  def create(conn, params) do
    with {:ok, _tenant_config} <- Provisioning.provision_tenant(params) do
      send_resp(conn, :created, "")
    end
  end

  def delete_by_slug(conn, %{"tenant_slug" => tenant_slug}) do
    with {:ok, _tenant} <- Provisioning.delete_tenant_by_slug(tenant_slug) do
      send_resp(conn, :no_content, "")
    end
  end
end
