#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.SystemModelsTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.DevicesFixtures

  alias Edgehog.Devices.{
    SystemModel,
    SystemModelPartNumber
  }

  describe "systemModels field" do
    @query """
    {
      systemModels {
        name
        handle
        partNumbers
        hardwareType {
          name
        }
        description
      }
    }
    """
    test "returns empty system models", %{conn: conn, api_path: api_path} do
      conn = get(conn, api_path, query: @query)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "systemModels" => []
               }
             }
    end

    test "returns system models if they're present", %{conn: conn, api_path: api_path} do
      hardware_type = hardware_type_fixture()

      %SystemModel{
        name: name,
        handle: handle,
        part_numbers: [%SystemModelPartNumber{part_number: part_number}]
      } = system_model_fixture(hardware_type: hardware_type)

      conn = get(conn, api_path, query: @query)

      assert %{
               "data" => %{
                 "systemModels" => [system_model]
               }
             } = json_response(conn, 200)

      assert system_model["name"] == name
      assert system_model["handle"] == handle
      assert system_model["partNumbers"] == [part_number]
      assert system_model["hardwareType"]["name"] == hardware_type.name
    end

    test "returns the default locale description", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      description = %{default_locale => "A system model", "it-IT" => "Un modello di sistema"}

      _system_model = system_model_fixture(description: description)

      conn = get(conn, api_path, query: @query)

      assert %{
               "data" => %{
                 "systemModels" => [system_model]
               }
             } = json_response(conn, 200)

      assert system_model["description"] == "A system model"
    end

    test "returns an explicit locale description", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      description = %{default_locale => "A system model", "it-IT" => "Un modello di sistema"}

      _system_model = system_model_fixture(description: description)

      conn =
        conn
        |> put_req_header("accept-language", "it-IT")
        |> get(api_path, query: @query)

      assert %{
               "data" => %{
                 "systemModels" => [system_model]
               }
             } = json_response(conn, 200)

      assert system_model["description"] == "Un modello di sistema"
    end

    test "returns description in the tenant's default locale for non existing locale", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      description = %{default_locale => "A system model", "it-IT" => "Un modello di sistema"}

      _system_model = system_model_fixture(description: description)

      conn =
        conn
        |> put_req_header("accept-language", "fr-FR")
        |> get(api_path, query: @query)

      assert %{
               "data" => %{
                 "systemModels" => [system_model]
               }
             } = json_response(conn, 200)

      assert system_model["description"] == "A system model"
    end

    test "returns no description when both user and tenant's locale are missing", %{
      conn: conn,
      api_path: api_path
    } do
      description = %{"it-IT" => "Un modello di sistema"}

      _system_model = system_model_fixture(description: description)

      conn =
        conn
        |> put_req_header("accept-language", "fr-FR")
        |> get(api_path, query: @query)

      assert %{
               "data" => %{
                 "systemModels" => [
                   %{
                     "description" => nil
                   }
                 ]
               }
             } = json_response(conn, 200)
    end
  end
end
