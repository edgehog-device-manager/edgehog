#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule EdgehogWeb.AdminAPI.Auth.Token do
  use Guardian, otp_app: :edgehog

  # This is used only when signing tokens, and we just want to verify them
  # However, we want to be able to generate tokens for testing purposes or
  # allow developers to generate tokens for their local dev enviorments.
  # For this reason we provide an implementation only for these envs
  if Mix.env() in [:test, :dev] do
    def subject_for_token(_resource, _claims) do
      {:ok, "test"}
    end
  else
    def subject_for_token(_resource, _claims) do
      {:error, :cannot_sign}
    end
  end

  def resource_from_claims(claims) do
    # TODO: at the moment we only check if the token contains an `e_ara` claim.
    # e_ara = Edgehog Admin REST API
    case Map.fetch(claims, "e_ara") do
      {:ok, claims} ->
        {:ok, %{claims: claims}}

      :error ->
        {:error, :no_valid_claims}
    end
  end
end
