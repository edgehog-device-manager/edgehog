#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Campaigns do
  @moduledoc """
  The Campaigns context.
  """

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  alias Edgehog.Campaigns.Channel

  graphql do
    root_level_errors? true

    queries do
      get Channel, :channel, :read do
        description "Returns a single channel."
      end

      list Channel, :channels, :read do
        description "Returns a list of channels."
        paginate_with :keyset
        relay? true
      end
    end

    mutations do
      create Channel, :create_channel, :create do
        relay_id_translations input: [target_group_ids: :device_group]
      end

      update Channel, :update_channel, :update do
        relay_id_translations input: [target_group_ids: :device_group]
      end

      destroy Channel, :delete_channel, :destroy
    end
  end

  resources do
    resource Channel
  end
end
