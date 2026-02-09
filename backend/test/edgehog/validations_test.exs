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

defmodule Edgehog.ValidationsTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Validation
  alias Edgehog.Validations

  describe "handle/1" do
    test "returns Match validation with correct pattern" do
      {Validation.Match, opts} = Validations.handle(:name)

      assert opts[:attribute] == :name
      assert opts[:match].source == "^[a-z][a-z\\d\\-]*$"
      assert opts[:message] =~ "should start with a lower case ASCII letter"
    end
  end

  describe "locale/1" do
    test "returns Match validation with correct pattern" do
      {Validation.Match, opts} = Validations.locale(:locale)

      assert opts[:attribute] == :locale
      assert opts[:match].source == "^[a-z]{2,3}-[A-Z]{2}$"
      assert opts[:message] == "is not a valid locale"
    end
  end

  describe "slug/1" do
    test "returns Match validation with correct pattern" do
      {Validation.Match, opts} = Validations.slug(:slug)

      assert opts[:attribute] == :slug
      assert opts[:match].source == "^[a-z\\d\\-]+$"
      assert opts[:message] =~ "should only contain lower case ASCII letters"
    end
  end

  describe "realm_name/1" do
    test "returns Match validation with correct pattern" do
      {Validation.Match, opts} = Validations.realm_name(:realm_name)

      assert opts[:attribute] == :realm_name
      assert opts[:match].source == "^[a-z][a-z0-9]{0,47}$"
      assert opts[:message] =~ "should only contain lower case ASCII letters"
      assert opts[:message] =~ "start with a lower case ASCII letter"
    end
  end
end
