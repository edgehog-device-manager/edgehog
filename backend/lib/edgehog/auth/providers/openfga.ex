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

defmodule Edgehog.Auth.Providers.OpenFGA do
  @moduledoc """
  OpenFGA Auth provider.

  This provider queries OpenFGA based on some model description to check tuples.
  """

  @behaviour Edgehog.Auth.Providers.Behaviour

  alias Edgehog.Auth.Providers.Behaviour
  alias Openfga.V1.OpenFGAService.Stub

  @impl Behaviour
  def init_context(args) do
    ctx = Map.new(args)

    {endpoint, ctx} = Map.pop!(ctx, :endpoint)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      ctx = Map.put(ctx, :channel, channel)

      {:ok, ctx}
    end
  end

  @impl Behaviour
  def check({subj, rel, obj}, %{channel: channel, store_id: store_id}) do
    tuple = %Openfga.V1.CheckRequestTupleKey{
      user: subj,
      relation: rel,
      object: obj
    }

    request = %Openfga.V1.CheckRequest{
      store_id: store_id,
      tuple_key: tuple
    }

    case Stub.check(channel, request) do
      {:ok, %{allowed: true}} -> :ok
      {:ok, %{allowed: false}} -> :notok
      error -> error
    end
  end

  @impl Behaviour
  def list_objects({subj, rel, type}, %{channel: channel, store_id: store_id}) do
    request = %Openfga.V1.ListObjectsRequest{
      store_id: store_id,
      type: type,
      relation: rel,
      user: subj
    }

    Stub.list_objects(channel, request)
  end

  @impl Behaviour
  def stream_list_objects({subj, rel, type}, %{channel: channel, store_id: store_id}) do
    request = %Openfga.V1.StreamedListObjectsRequest{
      store_id: store_id,
      type: type,
      relation: rel,
      user: subj
    }

    Stub.streamed_list_objects(channel, request)
  end
end
