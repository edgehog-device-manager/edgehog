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

defmodule Edgehog.Containers.Container.Env do
  @moduledoc """
  Helpers to resolve and encode the environment variables of a container.
  """

  @doc """
  Resolves the effective environment variables of a container given the
  environment configured on the container itself and the one provided at deploy
  time.

  When the strategy is `:merge`, the deploy-time variables are appended to the
  container ones, with the deploy-time variables winning on duplicate keys.
  When the strategy is `:override`, the deploy-time variables fully replace the
  container ones.
  """
  def resolve(container_env, deploy_env, :merge) do
    merge(container_env, deploy_env)
  end

  def resolve(_container_env, deploy_env, :override) do
    deploy_env
  end

  @doc """
  Encodes a list of environment variables into the `KEY=VALUE` format expected
  by the device.
  """
  def encode(env) when is_list(env) do
    Enum.map(env, fn var ->
      key(var) <> "=" <> value(var)
    end)
  end

  defp merge(base, overlay) do
    overlay_keys = MapSet.new(overlay, &normalize_key/1)

    base_overlaid = Enum.reject(base, &MapSet.member?(overlay_keys, normalize_key(&1)))

    base_overlaid ++ overlay
  end

  defp normalize_key(%{key: key}) when is_binary(key), do: key
  defp normalize_key(%{"key" => key}), do: key

  defp key(%{"key" => key}), do: key
  defp key(%{key: key}), do: key

  defp value(%{"value" => value}), do: value
  defp value(%{value: value}), do: value
end
