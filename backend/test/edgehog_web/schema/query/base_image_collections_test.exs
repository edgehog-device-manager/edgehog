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

defmodule EdgehogWeb.Schema.Query.BaseImageCollectionsTest do
  use EdgehogWeb.ConnCase

  import Edgehog.DevicesFixtures
  import Edgehog.BaseImagesFixtures

  alias Edgehog.BaseImages.BaseImageCollection

  describe "baseImageCollections field" do
    setup do
      hardware_type = hardware_type_fixture(name: "Fixture", handle: "fixture")
      system_model = system_model_fixture(hardware_type, name: "Fixture", handle: "fixture")

      {:ok, hardware_type: hardware_type, system_model: system_model}
    end

    @query """
    query {
      baseImageCollections {
        name
        handle
        systemModel {
          description {
            locale
            text
          }
        }
      }
    }
    """
    test "returns empty base image collections", %{conn: conn, api_path: api_path} do
      conn = get(conn, api_path, query: @query)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "baseImageCollections" => []
               }
             }
    end

    test "returns base image collections if they're present", %{
      conn: conn,
      api_path: api_path,
      system_model: system_model
    } do
      %BaseImageCollection{
        id: id,
        name: name,
        handle: handle
      } = base_image_collection_fixture(system_model)

      id = Absinthe.Relay.Node.to_global_id(:base_image_collection, id, EdgehogWeb.Schema)

      variables = %{id: id}

      conn = get(conn, api_path, query: @query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "baseImageCollections" => [
                   %{
                     "name" => name,
                     "handle" => handle,
                     "systemModel" => %{
                       "description" => nil
                     }
                   }
                 ]
               }
             }
    end

    test "returns the default locale description for system model", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant,
      hardware_type: hardware_type
    } do
      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "A base image collection"},
        %{locale: "it-IT", text: "Un modello di sistema"}
      ]

      system_model = system_model_fixture(hardware_type, descriptions: descriptions)

      _base_image_collection = base_image_collection_fixture(system_model)

      conn = get(conn, api_path, query: @query)

      assert %{
               "data" => %{
                 "baseImageCollections" => [
                   %{
                     "systemModel" => %{
                       "description" => %{
                         "locale" => ^default_locale,
                         "text" => "A base image collection"
                       }
                     }
                   }
                 ]
               }
             } = json_response(conn, 200)
    end

    test "returns the explicit locale system model description", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant,
      hardware_type: hardware_type
    } do
      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "A base image collection"},
        %{locale: "it-IT", text: "Un modello di sistema"}
      ]

      system_model = system_model_fixture(hardware_type, descriptions: descriptions)

      _base_image_collection = base_image_collection_fixture(system_model)

      conn =
        conn
        |> put_req_header("accept-language", "it-IT")
        |> get(api_path, query: @query)

      assert %{
               "data" => %{
                 "baseImageCollections" => [
                   %{
                     "systemModel" => %{
                       "description" => %{
                         "locale" => "it-IT",
                         "text" => "Un modello di sistema"
                       }
                     }
                   }
                 ]
               }
             } = json_response(conn, 200)
    end

    test "returns description in the tenant's default locale for non existing locale", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant,
      hardware_type: hardware_type
    } do
      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "A base image collection"},
        %{locale: "it-IT", text: "Un modello di sistema"}
      ]

      system_model = system_model_fixture(hardware_type, descriptions: descriptions)

      _base_image_collection = base_image_collection_fixture(system_model)

      conn =
        conn
        |> put_req_header("accept-language", "fr-FR")
        |> get(api_path, query: @query)

      assert %{
               "data" => %{
                 "baseImageCollections" => [
                   %{
                     "systemModel" => %{
                       "description" => %{
                         "locale" => ^default_locale,
                         "text" => "A base image collection"
                       }
                     }
                   }
                 ]
               }
             } = json_response(conn, 200)
    end

    test "returns no system model description when both user and tenant's locale are missing",
         %{
           conn: conn,
           api_path: api_path,
           hardware_type: hardware_type
         } do
      descriptions = [
        %{locale: "it-IT", text: "Un modello di sistema"}
      ]

      system_model = system_model_fixture(hardware_type, descriptions: descriptions)

      _base_image_collection = base_image_collection_fixture(system_model)

      conn =
        conn
        |> put_req_header("accept-language", "fr-FR")
        |> get(api_path, query: @query)

      assert %{
               "data" => %{
                 "baseImageCollections" => [
                   %{
                     "systemModel" => %{
                       "description" => nil
                     }
                   }
                 ]
               }
             } = json_response(conn, 200)
    end
  end
end
