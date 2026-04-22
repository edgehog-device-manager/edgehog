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

defmodule Openfga.V1.ConditionParamTypeRef.TypeName do
  @moduledoc false
  use Protobuf,
    enum: true,
    full_name: "openfga.v1.ConditionParamTypeRef.TypeName",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :TYPE_NAME_UNSPECIFIED, 0
  field :TYPE_NAME_ANY, 1
  field :TYPE_NAME_BOOL, 2
  field :TYPE_NAME_STRING, 3
  field :TYPE_NAME_INT, 4
  field :TYPE_NAME_UINT, 5
  field :TYPE_NAME_DOUBLE, 6
  field :TYPE_NAME_DURATION, 7
  field :TYPE_NAME_TIMESTAMP, 8
  field :TYPE_NAME_MAP, 9
  field :TYPE_NAME_LIST, 10
  field :TYPE_NAME_IPADDRESS, 11
end

defmodule Openfga.V1.AuthorizationModel.ConditionsEntry do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.AuthorizationModel.ConditionsEntry",
    map: true,
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: Openfga.V1.Condition
end

defmodule Openfga.V1.AuthorizationModel do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.AuthorizationModel",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :id, 1, type: :string, deprecated: false
  field :schema_version, 2, type: :string, deprecated: false
  field :type_definitions, 3, repeated: true, type: Openfga.V1.TypeDefinition, deprecated: false

  field :conditions, 4,
    repeated: true,
    type: Openfga.V1.AuthorizationModel.ConditionsEntry,
    map: true,
    deprecated: false
end

defmodule Openfga.V1.TypeDefinition.RelationsEntry do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.TypeDefinition.RelationsEntry",
    map: true,
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: Openfga.V1.Userset
end

defmodule Openfga.V1.TypeDefinition do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.TypeDefinition",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :type, 1, type: :string, deprecated: false

  field :relations, 2,
    repeated: true,
    type: Openfga.V1.TypeDefinition.RelationsEntry,
    map: true,
    deprecated: false

  field :metadata, 3, type: Openfga.V1.Metadata
end

defmodule Openfga.V1.Relation do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Relation",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :name, 1, type: :string, deprecated: false
  field :rewrite, 2, type: Openfga.V1.Userset, deprecated: false
  field :type_info, 3, type: Openfga.V1.RelationTypeInfo, json_name: "typeInfo"
end

defmodule Openfga.V1.RelationTypeInfo do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.RelationTypeInfo",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :directly_related_user_types, 1, repeated: true, type: Openfga.V1.RelationReference
end

defmodule Openfga.V1.Metadata.RelationsEntry do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Metadata.RelationsEntry",
    map: true,
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: Openfga.V1.RelationMetadata
end

defmodule Openfga.V1.Metadata do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Metadata",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :relations, 1, repeated: true, type: Openfga.V1.Metadata.RelationsEntry, map: true
  field :module, 2, type: :string, deprecated: false
  field :source_info, 3, type: Openfga.V1.SourceInfo
end

defmodule Openfga.V1.SourceInfo do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.SourceInfo",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :file, 1, type: :string, deprecated: false
end

defmodule Openfga.V1.RelationMetadata do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.RelationMetadata",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :directly_related_user_types, 1, repeated: true, type: Openfga.V1.RelationReference
  field :module, 2, type: :string, deprecated: false
  field :source_info, 3, type: Openfga.V1.SourceInfo
end

defmodule Openfga.V1.RelationReference do
  @moduledoc """
  RelationReference represents a relation of a particular object type (e.g. 'document#viewer').
  """

  use Protobuf,
    full_name: "openfga.v1.RelationReference",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  oneof(:relation_or_wildcard, 0)

  field :type, 1, type: :string, deprecated: false
  field :relation, 2, type: :string, oneof: 0, deprecated: false
  field :wildcard, 3, type: Openfga.V1.Wildcard, oneof: 0
  field :condition, 4, type: :string, deprecated: false
end

defmodule Openfga.V1.Wildcard do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Wildcard",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3
end

defmodule Openfga.V1.Usersets do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Usersets",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :child, 1, repeated: true, type: Openfga.V1.Userset, deprecated: false
end

defmodule Openfga.V1.Difference do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Difference",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  alias Openfga.V1.Userset

  field :base, 1, type: Userset, deprecated: false
  field :subtract, 2, type: Userset, deprecated: false
end

defmodule Openfga.V1.Userset do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Userset",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  alias Openfga.V1.Usersets

  oneof(:userset, 0)

  field :this, 1, type: Openfga.V1.DirectUserset, oneof: 0

  field :computed_userset, 2,
    type: Openfga.V1.ObjectRelation,
    json_name: "computedUserset",
    oneof: 0

  field :tuple_to_userset, 3,
    type: Openfga.V1.TupleToUserset,
    json_name: "tupleToUserset",
    oneof: 0

  field :union, 4, type: Usersets, oneof: 0
  field :intersection, 5, type: Usersets, oneof: 0
  field :difference, 6, type: Openfga.V1.Difference, oneof: 0
end

defmodule Openfga.V1.DirectUserset do
  @moduledoc """
  A DirectUserset is a sentinel message for referencing
  the direct members specified by an object/relation mapping.
  """

  use Protobuf,
    full_name: "openfga.v1.DirectUserset",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3
end

defmodule Openfga.V1.ObjectRelation do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ObjectRelation",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :object, 1, type: :string, deprecated: false
  field :relation, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.ComputedUserset do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ComputedUserset",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :relation, 1, type: :string, deprecated: false
end

defmodule Openfga.V1.TupleToUserset do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.TupleToUserset",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  alias Openfga.V1.ObjectRelation

  field :tupleset, 1, type: ObjectRelation, deprecated: false

  field :computed_userset, 2,
    type: ObjectRelation,
    json_name: "computedUserset",
    deprecated: false
end

defmodule Openfga.V1.Condition.ParametersEntry do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Condition.ParametersEntry",
    map: true,
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: Openfga.V1.ConditionParamTypeRef
end

defmodule Openfga.V1.Condition do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Condition",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :name, 1, type: :string, deprecated: false
  field :expression, 2, type: :string, deprecated: false

  field :parameters, 3,
    repeated: true,
    type: Openfga.V1.Condition.ParametersEntry,
    map: true,
    deprecated: false

  field :metadata, 4, type: Openfga.V1.ConditionMetadata
end

defmodule Openfga.V1.ConditionMetadata do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ConditionMetadata",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :module, 1, type: :string, deprecated: false
  field :source_info, 2, type: Openfga.V1.SourceInfo
end

defmodule Openfga.V1.ConditionParamTypeRef do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ConditionParamTypeRef",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :type_name, 1,
    type: Openfga.V1.ConditionParamTypeRef.TypeName,
    enum: true,
    deprecated: false

  field :generic_types, 2,
    repeated: true,
    type: Openfga.V1.ConditionParamTypeRef,
    deprecated: false
end
