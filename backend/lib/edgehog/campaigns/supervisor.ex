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

defmodule Edgehog.Campaigns.Supervisor do
  @moduledoc false
  use Supervisor

  alias Edgehog.Campaigns.ExecutorRegistry
  alias Edgehog.Campaigns.ExecutorSupervisor

  require Ash.Query

  @base_children [
    {Registry, name: ExecutorRegistry, keys: :unique},
    ExecutorSupervisor
  ]

  @mix_env Mix.env()

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    Supervisor.init(children(), strategy: :rest_for_one)
  end

  case @mix_env do
    :test ->
      defp children, do: @base_children

    _other ->
      defp children, do: @base_children ++ [update_campaigns_resumer()]

      defp update_campaigns_resumer do
        update_campaigns_stream =
          Edgehog.UpdateCampaigns.UpdateCampaign
          |> Ash.Query.for_read(:read_all_resumable)
          |> Ash.stream!()

        deployment_campaign_stream =
          Edgehog.DeploymentCampaigns.DeploymentCampaign
          |> Ash.Query.for_read(:read_all_resumable)
          |> Ash.stream!()

        campaigns_stream = Stream.concat(update_campaigns_stream, deployment_campaign_stream)

        {Edgehog.Campaigns.Resumer, campaigns_stream}
      end
  end
end
