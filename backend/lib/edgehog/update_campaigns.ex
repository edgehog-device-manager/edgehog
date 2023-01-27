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

defmodule Edgehog.UpdateCampaigns do
  @moduledoc """
  The UpdateCampaigns context.
  """

  import Ecto.Query, warn: false
  alias Edgehog.Repo

  alias Edgehog.UpdateCampaigns.UpdateChannel

  @doc """
  Returns the list of update_channels.

  ## Examples

      iex> list_update_channels()
      [%UpdateChannel{}, ...]

  """
  def list_update_channels do
    Repo.all(UpdateChannel)
  end

  @doc """
  Gets a single update_channel.

  Raises `Ecto.NoResultsError` if the Update channel does not exist.

  ## Examples

      iex> get_update_channel!(123)
      %UpdateChannel{}

      iex> get_update_channel!(456)
      ** (Ecto.NoResultsError)

  """
  def get_update_channel!(id), do: Repo.get!(UpdateChannel, id)

  @doc """
  Creates a update_channel.

  ## Examples

      iex> create_update_channel(%{field: value})
      {:ok, %UpdateChannel{}}

      iex> create_update_channel(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_update_channel(attrs \\ %{}) do
    %UpdateChannel{}
    |> UpdateChannel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a update_channel.

  ## Examples

      iex> update_update_channel(update_channel, %{field: new_value})
      {:ok, %UpdateChannel{}}

      iex> update_update_channel(update_channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_update_channel(%UpdateChannel{} = update_channel, attrs) do
    update_channel
    |> UpdateChannel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a update_channel.

  ## Examples

      iex> delete_update_channel(update_channel)
      {:ok, %UpdateChannel{}}

      iex> delete_update_channel(update_channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_update_channel(%UpdateChannel{} = update_channel) do
    Repo.delete(update_channel)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking update_channel changes.

  ## Examples

      iex> change_update_channel(update_channel)
      %Ecto.Changeset{data: %UpdateChannel{}}

  """
  def change_update_channel(%UpdateChannel{} = update_channel, attrs \\ %{}) do
    UpdateChannel.changeset(update_channel, attrs)
  end
end
