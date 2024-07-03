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

defmodule Edgehog.Changes.PublishNotification do
  use Ash.Resource.Change

  alias Edgehog.PubSub

  @impl Ash.Resource.Change
  def init(opts) do
    if is_atom(opts[:event_type]) do
      {:ok, opts}
    else
      {:error, "event_type must be an atom corresponding to an event supported by Edgehog.PubSub"}
    end
  end

  @impl Ash.Resource.Change
  def change(changeset, opts, _context) do
    event_type = Keyword.fetch!(opts, :event_type)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      publish_notification(event_type, result)
    end)
  end

  defp publish_notification(event_type, {:ok, resource} = result) do
    PubSub.publish!(event_type, resource)

    result
  end

  defp publish_notification(_event_type, result), do: result
end
