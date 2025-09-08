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

defmodule Edgehog.Campaigns.Channel.ErrorHandler do
  @moduledoc false

  def handle_error(error, context) do
    %{action: action} = context

    case action do
      :create -> target_ids_translation(error)
      :update -> target_ids_translation(error)
      _ -> error
    end
  end

  defp target_ids_translation(error) do
    if missing_target_ids?(error) do
      %{
        error
        | fields: [:target_group_ids],
          message: "One or more target groups could not be found"
      }
    else
      error
    end
  end

  defp missing_target_ids?(error) do
    error[:code] == "not_found"
  end
end
