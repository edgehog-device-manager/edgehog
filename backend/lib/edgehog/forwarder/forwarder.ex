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

defmodule Edgehog.Forwarder do
  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  graphql do
    root_level_errors? true

    queries do
      read_one Edgehog.Forwarder.Config, :forwarder_config, :get

      read_one Edgehog.Forwarder.Session, :forwarder_session, :get do
        relay_id_translations device_id: :device
      end
    end

    mutations do
      action Edgehog.Forwarder.Session, :request_forwarder_session, :request do
        relay_id_translations input: [device_id: :device]
      end
    end
  end

  resources do
    resource Edgehog.Forwarder.Config
    resource Edgehog.Forwarder.Session
  end
end
