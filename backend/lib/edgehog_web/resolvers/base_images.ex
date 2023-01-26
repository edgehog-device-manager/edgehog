#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule EdgehogWeb.Resolvers.BaseImages do
  alias Edgehog.BaseImages
  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.BaseImages.BaseImageCollection
  alias Edgehog.Devices
  alias Edgehog.Devices.SystemModel
  alias I18nHelpers.Ecto.Translator

  def find_base_image_collection(args, _resolution) do
    BaseImages.fetch_base_image_collection(args.id)
  end

  def list_base_image_collections(_args, _resolution) do
    base_image_collections = BaseImages.list_base_image_collections()

    {:ok, base_image_collections}
  end

  def create_base_image_collection(attrs, _resolution) do
    with {:ok, %SystemModel{} = system_model} <-
           Devices.fetch_system_model(attrs.system_model_id),
         {:ok, base_image_collection} <-
           BaseImages.create_base_image_collection(system_model, attrs) do
      {:ok, %{base_image_collection: base_image_collection}}
    end
  end

  def update_base_image_collection(attrs, _resolution) do
    with {:ok, %BaseImageCollection{} = base_image_collection} <-
           BaseImages.fetch_base_image_collection(attrs.base_image_collection_id),
         {:ok, %BaseImageCollection{} = base_image_collection} <-
           BaseImages.update_base_image_collection(base_image_collection, attrs) do
      {:ok, %{base_image_collection: base_image_collection}}
    end
  end

  def delete_base_image_collection(args, _resolution) do
    with {:ok, %BaseImageCollection{} = base_image_collection} <-
           BaseImages.fetch_base_image_collection(args.base_image_collection_id),
         {:ok, %BaseImageCollection{} = base_image_collection} <-
           BaseImages.delete_base_image_collection(base_image_collection) do
      {:ok, %{base_image_collection: base_image_collection}}
    end
  end

  def find_base_image(args, _resolution) do
    BaseImages.fetch_base_image(args.id)
  end

  def list_base_images_for_collection(%BaseImageCollection{} = collection, _args, _resolution) do
    base_images = BaseImages.list_base_images_for_collection(collection)

    {:ok, base_images}
  end

  def create_base_image(args, resolution) do
    default_locale = resolution.context.current_tenant.default_locale

    with {:ok, %BaseImageCollection{} = collection} <-
           BaseImages.fetch_base_image_collection(args.base_image_collection_id),
         :ok <- ensure_default_locale(args[:description], default_locale),
         :ok <- ensure_default_locale(args[:release_display_name], default_locale),
         args = wrap_localized_field(args, :description),
         args = wrap_localized_field(args, :release_display_name),
         {:ok, %BaseImage{} = base_image} <- BaseImages.create_base_image(collection, args) do
      {:ok, %{base_image: base_image}}
    end
  end

  # TODO: consider extracting all this functions dealing with locale wrapping/unwrapping
  # in a dedicated resolver/helper module

  # Only allow localized input text that uses the tenant default locale
  defp ensure_default_locale(nil, _default_locale), do: :ok
  defp ensure_default_locale(%{locale: default_locale}, default_locale), do: :ok
  defp ensure_default_locale(%{locale: _other}, _default), do: {:error, :not_default_locale}

  # If it's there, wraps a localized field in a map, as the context expects a map
  defp wrap_localized_field(args, field) when is_map_key(args, field) do
    case Map.fetch!(args, field) do
      %{locale: locale, text: text} ->
        Map.put(args, field, %{locale => text})

      _ ->
        args
    end
  end

  defp wrap_localized_field(args, _field), do: args

  def extract_localized_description(%BaseImage{} = base_image, _args, resolution) do
    # TODO: move this in a middleware
    extract_localized_field(base_image, :translated_description, resolution.context)
  end

  def extract_localized_release_display_name(%BaseImage{} = base_image, _args, resolution) do
    # TODO: move this in a middleware
    extract_localized_field(base_image, :translated_release_display_name, resolution.context)
  end

  defp extract_localized_field(%BaseImage{} = base_image, field, context) do
    %{
      preferred_locales: preferred_locales,
      tenant_locale: tenant_locale
    } = context

    translated_field =
      Translator.translate(base_image, preferred_locales, fallback_locale: tenant_locale)
      |> Map.fetch!(field)

    # TODO: fix the library to return nil on empty translations
    if translated_field == "" do
      {:ok, nil}
    else
      {:ok, translated_field}
    end
  end
end
