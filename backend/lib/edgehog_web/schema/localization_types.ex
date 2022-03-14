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

defmodule EdgehogWeb.Schema.LocalizationTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  @desc """
  Input object used to provide a localizedText as an input.
  """
  input_object :localized_text_input do
    @desc "The locale, expressed in the format indicated in RFC 5646 (e.g. en-US)"
    field :locale, non_null(:string)
    @desc "The localized text"
    field :text, non_null(:string)
  end

  @desc """
  A text expressed in a specific locale.
  """
  object :localized_text do
    @desc "The locale, expressed in the format indicated in RFC 5646 (e.g. en-US)"
    field :locale, non_null(:string)
    @desc "The localized text"
    field :text, non_null(:string)
  end
end
