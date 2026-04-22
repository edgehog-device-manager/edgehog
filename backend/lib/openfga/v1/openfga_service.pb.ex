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

defmodule Openfga.V1.ListObjectsRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ListObjectsRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :authorization_model_id, 2, type: :string, deprecated: false
  field :type, 3, type: :string, deprecated: false
  field :relation, 4, type: :string, deprecated: false
  field :user, 5, type: :string, deprecated: false
  field :contextual_tuples, 6, type: Openfga.V1.ContextualTupleKeys
  field :context, 7, type: Google.Protobuf.Struct
  field :consistency, 8, type: Openfga.V1.ConsistencyPreference, enum: true, deprecated: false
end

defmodule Openfga.V1.ListObjectsResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ListObjectsResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :objects, 1, repeated: true, type: :string, deprecated: false
end

defmodule Openfga.V1.ListUsersRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ListUsersRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :authorization_model_id, 2, type: :string, deprecated: false
  field :object, 3, type: Openfga.V1.Object, deprecated: false
  field :relation, 4, type: :string, deprecated: false
  field :user_filters, 5, repeated: true, type: Openfga.V1.UserTypeFilter, deprecated: false
  field :contextual_tuples, 6, repeated: true, type: Openfga.V1.TupleKey, deprecated: false
  field :context, 7, type: Google.Protobuf.Struct
  field :consistency, 8, type: Openfga.V1.ConsistencyPreference, enum: true, deprecated: false
end

defmodule Openfga.V1.ListUsersResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ListUsersResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :users, 1, repeated: true, type: Openfga.V1.User, deprecated: false
end

defmodule Openfga.V1.StreamedListObjectsRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.StreamedListObjectsRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :authorization_model_id, 2, type: :string, deprecated: false
  field :type, 3, type: :string, deprecated: false
  field :relation, 4, type: :string, deprecated: false
  field :user, 5, type: :string, deprecated: false
  field :contextual_tuples, 6, type: Openfga.V1.ContextualTupleKeys
  field :context, 7, type: Google.Protobuf.Struct
  field :consistency, 8, type: Openfga.V1.ConsistencyPreference, enum: true, deprecated: false
end

defmodule Openfga.V1.StreamedListObjectsResponse do
  @moduledoc """
  The response for a StreamedListObjects RPC.
  """

  use Protobuf,
    full_name: "openfga.v1.StreamedListObjectsResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :object, 1, type: :string, deprecated: false
end

defmodule Openfga.V1.ReadRequest do
  @moduledoc """
  Note: store_id is a ULID using pattern ^[ABCDEFGHJKMNPQRSTVWXYZ0-9]{26}$
  which excludes I, L, O, and U
  because of https://github.com/ulid/spec#encoding
  """

  use Protobuf,
    full_name: "openfga.v1.ReadRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :tuple_key, 2, type: Openfga.V1.ReadRequestTupleKey
  field :page_size, 3, type: Google.Protobuf.Int32Value, deprecated: false
  field :continuation_token, 4, type: :string, deprecated: false
  field :consistency, 5, type: Openfga.V1.ConsistencyPreference, enum: true, deprecated: false
end

defmodule Openfga.V1.ReadRequestTupleKey do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadRequestTupleKey",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :user, 1, type: :string, deprecated: false
  field :relation, 2, type: :string, deprecated: false
  field :object, 3, type: :string, deprecated: false
end

defmodule Openfga.V1.ReadResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tuples, 1, repeated: true, type: Openfga.V1.Tuple, deprecated: false
  field :continuation_token, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.WriteRequestWrites do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.WriteRequestWrites",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tuple_keys, 1, repeated: true, type: Openfga.V1.TupleKey, deprecated: false
  field :on_duplicate, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.WriteRequestDeletes do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.WriteRequestDeletes",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tuple_keys, 1,
    repeated: true,
    type: Openfga.V1.TupleKeyWithoutCondition,
    deprecated: false

  field :on_missing, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.WriteRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.WriteRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :writes, 2, type: Openfga.V1.WriteRequestWrites
  field :deletes, 3, type: Openfga.V1.WriteRequestDeletes
  field :authorization_model_id, 4, type: :string, deprecated: false
end

defmodule Openfga.V1.WriteResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.WriteResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3
end

defmodule Openfga.V1.CheckRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.CheckRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :tuple_key, 2, type: Openfga.V1.CheckRequestTupleKey, deprecated: false
  field :contextual_tuples, 3, type: Openfga.V1.ContextualTupleKeys
  field :authorization_model_id, 4, type: :string, deprecated: false
  field :trace, 5, type: :bool, deprecated: false
  field :context, 6, type: Google.Protobuf.Struct
  field :consistency, 7, type: Openfga.V1.ConsistencyPreference, enum: true, deprecated: false
end

defmodule Openfga.V1.CheckRequestTupleKey do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.CheckRequestTupleKey",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :user, 1, type: :string, deprecated: false
  field :relation, 2, type: :string, deprecated: false
  field :object, 3, type: :string, deprecated: false
end

defmodule Openfga.V1.CheckResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.CheckResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :allowed, 1, type: :bool, deprecated: false
  field :resolution, 2, type: :string
end

defmodule Openfga.V1.BatchCheckRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.BatchCheckRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :checks, 2, repeated: true, type: Openfga.V1.BatchCheckItem, deprecated: false
  field :authorization_model_id, 3, type: :string, deprecated: false
  field :consistency, 4, type: Openfga.V1.ConsistencyPreference, enum: true, deprecated: false
end

defmodule Openfga.V1.BatchCheckItem do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.BatchCheckItem",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tuple_key, 1, type: Openfga.V1.CheckRequestTupleKey, deprecated: false
  field :contextual_tuples, 2, type: Openfga.V1.ContextualTupleKeys
  field :context, 3, type: Google.Protobuf.Struct
  field :correlation_id, 4, type: :string, deprecated: false
end

defmodule Openfga.V1.BatchCheckResponse.ResultEntry do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.BatchCheckResponse.ResultEntry",
    map: true,
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: Openfga.V1.BatchCheckSingleResult
end

defmodule Openfga.V1.BatchCheckResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.BatchCheckResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :result, 1,
    repeated: true,
    type: Openfga.V1.BatchCheckResponse.ResultEntry,
    map: true,
    deprecated: false
end

defmodule Openfga.V1.BatchCheckSingleResult do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.BatchCheckSingleResult",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  oneof(:check_result, 0)

  field :allowed, 1, type: :bool, oneof: 0
  field :error, 2, type: Openfga.V1.CheckError, oneof: 0
end

defmodule Openfga.V1.CheckError do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.CheckError",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  oneof(:code, 0)

  field :input_error, 1, type: Openfga.V1.ErrorCode, enum: true, oneof: 0
  field :internal_error, 2, type: Openfga.V1.InternalErrorCode, enum: true, oneof: 0
  field :message, 3, type: :string
end

defmodule Openfga.V1.ExpandRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ExpandRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :tuple_key, 2, type: Openfga.V1.ExpandRequestTupleKey, deprecated: false
  field :authorization_model_id, 3, type: :string, deprecated: false
  field :consistency, 4, type: Openfga.V1.ConsistencyPreference, enum: true, deprecated: false
  field :contextual_tuples, 5, type: Openfga.V1.ContextualTupleKeys
end

defmodule Openfga.V1.ExpandRequestTupleKey do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ExpandRequestTupleKey",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :relation, 1, type: :string, deprecated: false
  field :object, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.ExpandResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ExpandResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tree, 1, type: Openfga.V1.UsersetTree
end

defmodule Openfga.V1.ReadAuthorizationModelRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadAuthorizationModelRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :id, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.ReadAuthorizationModelResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadAuthorizationModelResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :authorization_model, 1, type: Openfga.V1.AuthorizationModel
end

defmodule Openfga.V1.WriteAuthorizationModelRequest.ConditionsEntry do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.WriteAuthorizationModelRequest.ConditionsEntry",
    map: true,
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: Openfga.V1.Condition
end

defmodule Openfga.V1.WriteAuthorizationModelRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.WriteAuthorizationModelRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :type_definitions, 2, repeated: true, type: Openfga.V1.TypeDefinition, deprecated: false
  field :schema_version, 3, type: :string, deprecated: false

  field :conditions, 4,
    repeated: true,
    type: Openfga.V1.WriteAuthorizationModelRequest.ConditionsEntry,
    map: true,
    deprecated: false
end

defmodule Openfga.V1.WriteAuthorizationModelResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.WriteAuthorizationModelResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :authorization_model_id, 1, type: :string, deprecated: false
end

defmodule Openfga.V1.ReadAuthorizationModelsRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadAuthorizationModelsRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :page_size, 2, type: Google.Protobuf.Int32Value, deprecated: false
  field :continuation_token, 3, type: :string, deprecated: false
end

defmodule Openfga.V1.ReadAuthorizationModelsResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadAuthorizationModelsResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :authorization_models, 1,
    repeated: true,
    type: Openfga.V1.AuthorizationModel,
    deprecated: false

  field :continuation_token, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.WriteAssertionsRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.WriteAssertionsRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :authorization_model_id, 2, type: :string, deprecated: false
  field :assertions, 3, repeated: true, type: Openfga.V1.Assertion, deprecated: false
end

defmodule Openfga.V1.WriteAssertionsResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.WriteAssertionsResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3
end

defmodule Openfga.V1.ReadAssertionsRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadAssertionsRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :authorization_model_id, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.ReadAssertionsResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadAssertionsResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :authorization_model_id, 1, type: :string, deprecated: false
  field :assertions, 2, repeated: true, type: Openfga.V1.Assertion
end

defmodule Openfga.V1.ReadChangesRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadChangesRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :type, 2, type: :string, deprecated: false
  field :page_size, 3, type: Google.Protobuf.Int32Value, deprecated: false
  field :continuation_token, 4, type: :string, deprecated: false
  field :start_time, 5, type: Google.Protobuf.Timestamp, deprecated: false
end

defmodule Openfga.V1.ReadChangesResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ReadChangesResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :changes, 1, repeated: true, type: Openfga.V1.TupleChange, deprecated: false
  field :continuation_token, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.CreateStoreRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.CreateStoreRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :name, 1, type: :string, deprecated: false
end

defmodule Openfga.V1.CreateStoreResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.CreateStoreResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  alias Google.Protobuf.Timestamp

  field :id, 1, type: :string, deprecated: false
  field :name, 2, type: :string, deprecated: false
  field :created_at, 3, type: Timestamp, deprecated: false
  field :updated_at, 4, type: Timestamp, deprecated: false
end

defmodule Openfga.V1.UpdateStoreRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.UpdateStoreRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
  field :name, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.UpdateStoreResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.UpdateStoreResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  alias Google.Protobuf.Timestamp

  field :id, 1, type: :string, deprecated: false
  field :name, 2, type: :string, deprecated: false
  field :created_at, 3, type: Timestamp, deprecated: false
  field :updated_at, 4, type: Timestamp, deprecated: false
end

defmodule Openfga.V1.DeleteStoreRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.DeleteStoreRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
end

defmodule Openfga.V1.DeleteStoreResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.DeleteStoreResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3
end

defmodule Openfga.V1.GetStoreRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.GetStoreRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :store_id, 1, type: :string, deprecated: false
end

defmodule Openfga.V1.GetStoreResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.GetStoreResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  alias Google.Protobuf.Timestamp

  field :id, 1, type: :string, deprecated: false
  field :name, 2, type: :string, deprecated: false
  field :created_at, 3, type: Timestamp, deprecated: false
  field :updated_at, 4, type: Timestamp, deprecated: false
  field :deleted_at, 5, type: Timestamp
end

defmodule Openfga.V1.ListStoresRequest do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ListStoresRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :page_size, 1, type: Google.Protobuf.Int32Value, deprecated: false
  field :continuation_token, 2, type: :string, deprecated: false
  field :name, 3, type: :string, deprecated: false
end

defmodule Openfga.V1.ListStoresResponse do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ListStoresResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :stores, 1, repeated: true, type: Openfga.V1.Store, deprecated: false
  field :continuation_token, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.AssertionTupleKey do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.AssertionTupleKey",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :object, 1, type: :string, deprecated: false
  field :relation, 2, type: :string, deprecated: false
  field :user, 3, type: :string, deprecated: false
end

defmodule Openfga.V1.Assertion do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Assertion",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tuple_key, 1, type: Openfga.V1.AssertionTupleKey, deprecated: false
  field :expectation, 2, type: :bool, deprecated: false
  field :contextual_tuples, 3, repeated: true, type: Openfga.V1.TupleKey, deprecated: false
  field :context, 4, type: Google.Protobuf.Struct, deprecated: false
end

defmodule Openfga.V1.Assertions do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Assertions",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :assertions, 1, repeated: true, type: Openfga.V1.Assertion, deprecated: false
end
