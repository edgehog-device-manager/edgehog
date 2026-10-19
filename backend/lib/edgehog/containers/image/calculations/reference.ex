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

defmodule Edgehog.Containers.Image.Calculations.Reference do
  @moduledoc """
  Calculates the full OCI/Docker reference string from an image's discrete segments.
  """
  use Ash.Resource.Calculation

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context) do
    [:registry_host, :registry_port, :repository, :image, :tag, :digest]
  end

  @impl Ash.Resource.Calculation
  def calculate(records, _opts, _context) do
    Enum.map(records, &build_reference/1)
  end

  defp build_reference(record) do
    registry = build_registry(record.registry_host, record.registry_port)

    prefix =
      [registry, record.repository]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("/")

    name_with_prefix =
      if prefix == "" do
        record.image
      else
        "#{prefix}/#{record.image}"
      end

    name_with_prefix
    |> append_tag(record.tag)
    |> append_digest(record.digest)
  end

  defp build_registry(nil, _port), do: nil
  defp build_registry(host, nil), do: host
  defp build_registry(host, port), do: "#{host}:#{port}"

  defp append_tag(ref, nil), do: ref
  defp append_tag(ref, tag), do: "#{ref}:#{tag}"

  defp append_digest(ref, nil), do: ref
  defp append_digest(ref, digest), do: "#{ref}@#{digest}"
end
