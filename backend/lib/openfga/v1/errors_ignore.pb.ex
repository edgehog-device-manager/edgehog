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

defmodule Openfga.V1.AuthErrorCode do
  use Protobuf,
    enum: true,
    full_name: "openfga.v1.AuthErrorCode",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :no_auth_error, 0
  field :auth_failed_invalid_subject, 1001
  field :auth_failed_invalid_audience, 1002
  field :auth_failed_invalid_issuer, 1003
  field :invalid_claims, 1004
  field :auth_failed_invalid_bearer_token, 1005
  field :bearer_token_missing, 1010
  field :unauthenticated, 1500
  field :forbidden, 1600
end

defmodule Openfga.V1.ErrorCode do
  use Protobuf,
    enum: true,
    full_name: "openfga.v1.ErrorCode",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :no_error, 0
  field :validation_error, 2000
  field :authorization_model_not_found, 2001
  field :authorization_model_resolution_too_complex, 2002
  field :invalid_write_input, 2003
  field :cannot_allow_duplicate_tuples_in_one_request, 2004
  field :cannot_allow_duplicate_types_in_one_request, 2005
  field :cannot_allow_multiple_references_to_one_relation, 2006
  field :invalid_continuation_token, 2007
  field :invalid_tuple_set, 2008
  field :invalid_check_input, 2009
  field :invalid_expand_input, 2010
  field :unsupported_user_set, 2011
  field :invalid_object_format, 2012
  field :write_failed_due_to_invalid_input, 2017
  field :authorization_model_assertions_not_found, 2018
  field :latest_authorization_model_not_found, 2020
  field :type_not_found, 2021
  field :relation_not_found, 2022
  field :empty_relation_definition, 2023
  field :invalid_user, 2025
  field :invalid_tuple, 2027
  field :unknown_relation, 2028
  field :store_id_invalid_length, 2030
  field :assertions_too_many_items, 2033
  field :id_too_long, 2034
  field :authorization_model_id_too_long, 2036
  field :tuple_key_value_not_specified, 2037
  field :tuple_keys_too_many_or_too_few_items, 2038
  field :page_size_invalid, 2039
  field :param_missing_value, 2040
  field :difference_base_missing_value, 2041
  field :subtract_base_missing_value, 2042
  field :object_too_long, 2043
  field :relation_too_long, 2044
  field :type_definitions_too_few_items, 2045
  field :type_invalid_length, 2046
  field :type_invalid_pattern, 2047
  field :relations_too_few_items, 2048
  field :relations_too_long, 2049
  field :relations_invalid_pattern, 2050
  field :object_invalid_pattern, 2051
  field :query_string_type_continuation_token_mismatch, 2052
  field :exceeded_entity_limit, 2053
  field :invalid_contextual_tuple, 2054
  field :duplicate_contextual_tuple, 2055
  field :invalid_authorization_model, 2056
  field :unsupported_schema_version, 2057
  field :cancelled, 2058
  field :invalid_start_time, 2059
end

defmodule Openfga.V1.UnprocessableContentErrorCode do
  use Protobuf,
    enum: true,
    full_name: "openfga.v1.UnprocessableContentErrorCode",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :no_throttled_error_code, 0
  field :throttled_timeout_error, 3500
end

defmodule Openfga.V1.InternalErrorCode do
  use Protobuf,
    enum: true,
    full_name: "openfga.v1.InternalErrorCode",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :no_internal_error, 0
  field :internal_error, 4000
  field :deadline_exceeded, 4004
  field :already_exists, 4005
  field :resource_exhausted, 4006
  field :failed_precondition, 4007
  field :aborted, 4008
  field :out_of_range, 4009
  field :unavailable, 4010
  field :data_loss, 4011
end

defmodule Openfga.V1.NotFoundErrorCode do
  use Protobuf,
    enum: true,
    full_name: "openfga.v1.NotFoundErrorCode",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :no_not_found_error, 0
  field :undefined_endpoint, 5000
  field :store_id_not_found, 5002
  field :unimplemented, 5004
end

defmodule Openfga.V1.ValidationErrorMessageResponse do
  use Protobuf,
    full_name: "openfga.v1.ValidationErrorMessageResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :code, 1, type: Openfga.V1.ErrorCode, enum: true
  field :message, 2, type: :string
end

defmodule Openfga.V1.UnauthenticatedResponse do
  use Protobuf,
    full_name: "openfga.v1.UnauthenticatedResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :code, 1, type: Openfga.V1.ErrorCode, enum: true
  field :message, 2, type: :string
end

defmodule Openfga.V1.UnprocessableContentMessageResponse do
  use Protobuf,
    full_name: "openfga.v1.UnprocessableContentMessageResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :code, 1, type: Openfga.V1.UnprocessableContentErrorCode, enum: true
  field :message, 2, type: :string
end

defmodule Openfga.V1.InternalErrorMessageResponse do
  use Protobuf,
    full_name: "openfga.v1.InternalErrorMessageResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :code, 1, type: Openfga.V1.InternalErrorCode, enum: true
  field :message, 2, type: :string
end

defmodule Openfga.V1.PathUnknownErrorMessageResponse do
  use Protobuf,
    full_name: "openfga.v1.PathUnknownErrorMessageResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :code, 1, type: Openfga.V1.NotFoundErrorCode, enum: true
  field :message, 2, type: :string
end

defmodule Openfga.V1.AbortedMessageResponse do
  use Protobuf,
    full_name: "openfga.v1.AbortedMessageResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :code, 1, type: :string
  field :message, 2, type: :string
end

defmodule Openfga.V1.ErrorMessageRequest do
  use Protobuf,
    full_name: "openfga.v1.ErrorMessageRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3
end

defmodule Openfga.V1.ForbiddenResponse do
  use Protobuf,
    full_name: "openfga.v1.ForbiddenResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :code, 1, type: Openfga.V1.AuthErrorCode, enum: true
  field :message, 2, type: :string
end
