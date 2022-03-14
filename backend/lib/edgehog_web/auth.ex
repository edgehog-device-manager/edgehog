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
# SPDX-License-Identifier: Apache-2.0
#

defmodule EdgehogWeb.Auth do
  alias Edgehog.Config
  alias EdgehogWeb.Auth.Pipeline

  def init(opts) do
    Pipeline.init(opts)
  end

  def call(conn, opts) do
    unless Config.authentication_disabled?() do
      Pipeline.call(conn, opts)
    else
      # TODO: when we add Authz this path will probably have to
      # put some type of all-access Authz in the GraphQL context
      conn
    end
  end
end
