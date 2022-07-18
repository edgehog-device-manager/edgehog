#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Error do
  @moduledoc """
  Module used to normalize all errors in Edghog, so that they can be shown by the API.
  """

  require Logger
  alias __MODULE__

  defstruct [:code, :message, :status_code, :key]

  # Error Tuples

  # Regular errors
  def normalize({:error, reason}) do
    handle(reason)
  end

  # Ecto transaction errors
  def normalize({:error, _operation, reason, _changes}) do
    handle(reason)
  end

  # Unhandled errors
  def normalize(other) do
    handle(other)
  end

  defp handle(code) when is_atom(code) do
    {status, message} = metadata(code)

    %Error{
      code: code,
      message: message,
      status_code: status
    }
  end

  defp handle(errors) when is_list(errors) do
    Enum.map(errors, &handle/1)
  end

  defp handle(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {err, _opts} -> err end)
    |> Enum.map(fn
      {_k, v} when is_map(v) ->
        # Nested changeset, inner errors are already a rendered map
        from_rendered_changeset_errors(v)

      {k, v} ->
        %Error{
          code: :validation,
          message: String.capitalize("#{k} #{v}"),
          status_code: 422
        }
    end)
  end

  defp handle(%{status: status, response: response} = error)
       when is_struct(error, Astarte.Client.APIError) do
    case response do
      # detail already includes an error message
      %{"errors" => %{"detail" => error_message}} ->
        %Error{
          code: :astarte_api_error,
          message: error_message,
          status_code: status
        }

      # This probably comes from a changeset error, translate it
      %{"errors" => errors} when is_map(errors) and status == 422 ->
        from_rendered_changeset_errors(errors)

      # If something else comes up, we return the status and print out an error
      response ->
        Logger.warn("Unhandled API Error: #{inspect(response)}")

        %Error{
          code: :astarte_api_error,
          message: Jason.encode!(response),
          status_code: status
        }
    end
  end

  defp handle(other) do
    Logger.warn("Unhandled error term: #{inspect(other)}")
    handle(:unknown)
  end

  defp from_rendered_changeset_errors(changeset_errors) do
    Enum.map(changeset_errors, fn {k, error_messages} ->
      # Emit an error struct for each error message on a key
      Enum.map(error_messages, fn error_message ->
        %Error{
          code: :astarte_api_error,
          message: String.capitalize("#{k} #{error_message}"),
          status_code: 422
        }
      end)
    end)
  end

  defp metadata(:unauthenticated), do: {401, "Login required"}
  defp metadata(:unauthorized), do: {403, "Unauthorized"}
  defp metadata(:not_found), do: {404, "Resource not found"}

  defp metadata(:not_default_locale) do
    {422, "The default tenant locale must be used when creating or updating this resource"}
  end

  defp metadata(:unknown), do: {500, "Something went wrong"}

  defp metadata(code) do
    Logger.warn("Unhandled error code: #{inspect(code)}")
    {422, to_string(code)}
  end
end
