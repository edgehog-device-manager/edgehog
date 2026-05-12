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

defmodule Edgehog.Auth.Providers.OpenFGATest do
  @moduledoc false

  use ExUnit.Case, async: true
  use Mimic

  alias Edgehog.Auth.Providers.OpenFGA

  describe "init_context/1" do
    test "inits context with valid openfga config" do
      config = localhost_config()

      expect(GRPC.Stub, :connect, fn _args ->
        {:ok, :mychannel}
      end)

      OpenFGA.init_context(config)
    end
  end

  describe "check/2" do
    setup do
      config = localhost_config()

      expect(GRPC.Stub, :connect, fn _args ->
        {:ok, :mychannel}
      end)

      {:ok, context} = OpenFGA.init_context(config)
      %{context: context}
    end

    test "checks tuples", %{context: context} do
      tuple = Edgehog.TupleFixtures.tuple()

      expect(Openfga.V1.OpenFGAService.Stub, :check, fn _channel, request ->
        %Openfga.V1.CheckRequest{
          tuple_key: %Openfga.V1.CheckRequestTupleKey{
            user: subject,
            relation: relationship,
            object: object
          }
        } = request

        {t_subj, t_rel, t_obj} = tuple

        assert subject == t_subj
        assert relationship == t_rel
        assert object == t_obj

        {:ok, %Openfga.V1.CheckResponse{allowed: true}}
      end)

      OpenFGA.check(tuple, context)
    end
  end

  defp localhost_config do
    [
      endpoint: "localhost:8081",
      store_id: "some-store-id",
      auth_model_id: "some-auth-model-id"
    ]
  end
end
