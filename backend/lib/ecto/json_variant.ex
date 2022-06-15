#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Ecto.JSONVariant do
  use Ecto.Type

  alias __MODULE__

  # TODO: add support for array values
  @supported_types [
    :double,
    :integer,
    :boolean,
    :longinteger,
    :string,
    :binaryblob,
    :datetime
  ]

  defstruct [:type, :value]

  @impl true
  def type, do: :map

  @impl true
  def cast(%{"type" => type, "value" => value}) when is_atom(type) and type in @supported_types do
    do_cast(type, value)
  end

  def cast(%{"type" => type, "value" => value}) when is_binary(type) do
    with {:ok, type} <- type_string_to_atom(type) do
      do_cast(type, value)
    end
  end

  def cast(%{type: type, value: value}) when is_atom(type) and type in @supported_types do
    do_cast(type, value)
  end

  def cast(%{type: type, value: value}) when is_binary(type) do
    with {:ok, type} <- type_string_to_atom(type) do
      do_cast(type, value)
    end
  end

  def cast(_) do
    :error
  end

  defp do_cast(type, value) do
    with {:ok, value} <- cast_fun(type).(value) do
      {:ok, struct!(__MODULE__, type: type, value: value)}
    end
  end

  defp cast_fun(:double), do: &Ecto.Type.cast(:float, &1)
  defp cast_fun(:integer), do: &cast_integer/1
  defp cast_fun(:boolean), do: &Ecto.Type.cast(:boolean, &1)
  defp cast_fun(:longinteger), do: &cast_longinteger/1
  defp cast_fun(:string), do: &cast_string/1
  defp cast_fun(:binaryblob), do: &cast_binaryblob/1
  defp cast_fun(:datetime), do: &Ecto.Type.cast(:utc_datetime_usec, &1)

  defp cast_integer(term) when is_binary(term) do
    case Integer.parse(term) do
      {integer, ""} when abs(integer) <= 0x7FFF_FFFF -> {:ok, integer}
      _ -> :error
    end
  end

  defp cast_integer(term) when is_integer(term) and abs(term) <= 0x7FFF_FFFF, do: {:ok, term}
  defp cast_integer(term) when is_integer(term), do: {:error, message: "is out of range"}
  defp cast_integer(_), do: :error

  defp cast_longinteger(term) when is_binary(term) do
    case Integer.parse(term) do
      {integer, ""} when abs(integer) <= 0x7FFF_FFFF_FFFF_FFFF -> {:ok, integer}
      _ -> :error
    end
  end

  defp cast_longinteger(term) when is_integer(term) and abs(term) <= 0x7FFF_FFFF_FFFF_FFFF do
    {:ok, term}
  end

  defp cast_longinteger(_), do: :error

  defp cast_string(term) when is_binary(term) do
    if String.valid?(term) do
      {:ok, term}
    else
      :error
    end
  end

  defp cast_string(_), do: :error

  defp cast_binaryblob(term) when is_binary(term) do
    case Base.decode64(term) do
      {:ok, value} -> {:ok, value}
      _ -> :error
    end
  end

  defp cast_binaryblob(_), do: :error

  defp type_string_to_atom("double"), do: {:ok, :double}
  defp type_string_to_atom("integer"), do: {:ok, :integer}
  defp type_string_to_atom("boolean"), do: {:ok, :boolean}
  defp type_string_to_atom("longinteger"), do: {:ok, :longinteger}
  defp type_string_to_atom("string"), do: {:ok, :string}
  defp type_string_to_atom("binaryblob"), do: {:ok, :binaryblob}
  defp type_string_to_atom("datetime"), do: {:ok, :datetime}
  defp type_string_to_atom(_), do: :error

  @impl true
  def dump(%JSONVariant{type: type, value: value}) when type in @supported_types do
    with {:ok, value} <- dump_fun(type).(value) do
      {:ok, %{t: Atom.to_string(type), v: value}}
    end
  end

  def dump(_), do: :error

  defp dump_fun(:double), do: &Ecto.Type.dump(:float, &1)
  defp dump_fun(:integer), do: &Ecto.Type.dump(:integer, &1)
  defp dump_fun(:boolean), do: &Ecto.Type.dump(:boolean, &1)
  defp dump_fun(:longinteger), do: &Ecto.Type.dump(:integer, &1)
  defp dump_fun(:string), do: &Ecto.Type.dump(:string, &1)
  defp dump_fun(:binaryblob), do: &dump_binaryblob/1
  defp dump_fun(:datetime), do: &dump_datetime/1

  defp dump_binaryblob(value) do
    with {:ok, binary} <- Ecto.Type.dump(:binary, value) do
      {:ok, Base.encode64(binary)}
    end
  end

  defp dump_datetime(value) do
    with {:ok, datetime} <- Ecto.Type.dump(:utc_datetime_usec, value) do
      {:ok, DateTime.to_iso8601(datetime)}
    end
  end

  @impl true
  def load(%{"t" => type_string, "v" => value}) do
    with {:ok, type} <- type_string_to_atom(type_string),
         {:ok, value} <- load_fun(type).(value) do
      {:ok, struct!(__MODULE__, type: type, value: value)}
    end
  end

  def load(_), do: :error

  defp load_fun(:double), do: &Ecto.Type.load(:float, &1)
  defp load_fun(:integer), do: &Ecto.Type.load(:integer, &1)
  defp load_fun(:boolean), do: &Ecto.Type.load(:boolean, &1)
  defp load_fun(:longinteger), do: &Ecto.Type.load(:integer, &1)
  defp load_fun(:string), do: &Ecto.Type.load(:string, &1)
  defp load_fun(:binaryblob), do: &load_binaryblob/1
  defp load_fun(:datetime), do: &load_datetime/1

  defp load_binaryblob(value) do
    case Base.decode64(value) do
      {:ok, binary} -> Ecto.Type.load(:binary, binary)
      _ -> :error
    end
  end

  defp load_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, 0} -> Ecto.Type.load(:utc_datetime_usec, datetime)
      _ -> :error
    end
  end
end
