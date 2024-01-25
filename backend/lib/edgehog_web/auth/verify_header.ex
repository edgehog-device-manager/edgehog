#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Auth.VerifyHeader do
  @moduledoc """
  This is a wrapper around `Guardian.Plug.VerifyHeader` that allows to recover
  the JWT public key dynamically using the tenant contained in the connection
  """
  require Logger

  alias Guardian.Plug.VerifyHeader, as: GuardianVerifyHeader
  alias JOSE.JWK

  def init(opts) do
    GuardianVerifyHeader.init(opts)
  end

  def call(conn, opts) do
    public_key = get_public_key(conn)

    opts = Keyword.merge(opts, secret: public_key)

    GuardianVerifyHeader.call(conn, opts)
  end

  defp get_public_key(conn) do
    tenant = Ash.PlugHelpers.get_tenant(conn)

    case JWK.from_pem(tenant.public_key) do
      %JWK{} = public_key ->
        public_key

      _other ->
        Logger.warning("Invalid JWT public key PEM in tenant: #{inspect(tenant)}.")
        # We just return nil and this will make auth fail down the pipeline
        nil
    end
  end
end
