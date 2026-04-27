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

defmodule Edgehog.Files.Compressor do
  @moduledoc false

  def compress(%Plug.Upload{} = upload, :gz) do
    compressed_path =
      Path.join(System.tmp_dir!(), "#{Ash.UUIDv7.generate()}.gz")

    input = File.stream!(upload.path, 64_000, [])
    output = File.open!(compressed_path, [:write, :binary])

    z = :zlib.open()
    :ok = :zlib.deflateInit(z, :default, :deflated, 31, 8, :default)

    Enum.each(input, fn chunk ->
      compressed = :zlib.deflate(z, chunk)
      IO.binwrite(output, compressed)
    end)

    final = :zlib.deflate(z, <<>>, :finish)
    IO.binwrite(output, final)

    :zlib.close(z)
    File.close(output)

    {:ok,
     %Plug.Upload{
       path: compressed_path,
       filename: upload.filename <> ".gz",
       content_type: "application/gzip"
     }}
  rescue
    error -> {:error, error}
  end

  def compress(%Plug.Upload{} = upload, :lz4) do
    compressed_path =
      Path.join(System.tmp_dir!(), "#{Ash.UUIDv7.generate()}.lz4")

    upload.path
    |> File.read!()
    |> NimbleLZ4.compress_frame()
    |> then(&File.write!(compressed_path, &1))

    {:ok,
     %Plug.Upload{
       path: compressed_path,
       filename: upload.filename <> ".lz4",
       content_type: "application/x-lz4"
     }}
  rescue
    error -> {:error, error}
  end
end
