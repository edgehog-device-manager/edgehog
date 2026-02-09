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

defmodule EdgehogWeb.ErrorHelpersTest do
  use ExUnit.Case, async: true

  alias EdgehogWeb.ErrorHelpers

  describe "translate_error/1" do
    test "translates simple error message" do
      result = ErrorHelpers.translate_error({"is invalid", []})

      assert is_binary(result)
    end

    test "translates error message with count using plural rules" do
      result = ErrorHelpers.translate_error({"should have %{count} item(s)", [count: 3]})

      assert is_binary(result)
    end

    test "translates error message with count of 1" do
      result = ErrorHelpers.translate_error({"should have %{count} item(s)", [count: 1]})

      assert is_binary(result)
    end

    test "translates error message with other options" do
      result = ErrorHelpers.translate_error({"is invalid format %{format}", [format: "email"]})

      assert is_binary(result)
    end

    test "handles empty options" do
      result = ErrorHelpers.translate_error({"can't be blank", []})

      assert is_binary(result)
    end
  end
end
