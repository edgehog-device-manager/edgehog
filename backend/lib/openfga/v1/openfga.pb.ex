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

defmodule Openfga.V1.TupleOperation do
  @moduledoc """
  buf:lint:ignore ENUM_ZERO_VALUE_SUFFIX
  """

  use Protobuf,
    enum: true,
    full_name: "openfga.v1.TupleOperation",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :TUPLE_OPERATION_WRITE, 0
  field :TUPLE_OPERATION_DELETE, 1
end

defmodule Openfga.V1.Object do
  @moduledoc """
  Object represents an OpenFGA Object.

  An Object is composed of a type and identifier (e.g. 'document:1')

  See https://openfga.dev/docs/concepts#what-is-an-object
  """

  use Protobuf,
    full_name: "openfga.v1.Object",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :type, 1, type: :string, deprecated: false
  field :id, 2, type: :string, deprecated: false
end

defmodule Openfga.V1.User do
  @moduledoc """
  User.

  Represents any possible value for a user (subject or principal). Can be a:
  - Specific user object e.g.: 'user:will', 'folder:marketing', 'org:contoso', ...)
  - Specific userset (e.g. 'group:engineering#member')
  - Public-typed wildcard (e.g. 'user:*')

  See https://openfga.dev/docs/concepts#what-is-a-user
  """

  use Protobuf, full_name: "openfga.v1.User", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  oneof(:user, 0)

  field :object, 1, type: Openfga.V1.Object, oneof: 0
  field :userset, 2, type: Openfga.V1.UsersetUser, oneof: 0
  field :wildcard, 3, type: Openfga.V1.TypedWildcard, oneof: 0
end

defmodule Openfga.V1.UsersetUser do
  @moduledoc """
  Userset.

  A set or group of users, represented in the `<type>:<id>#<relation>` format

  `group:fga#member` represents all members of group FGA, not to be confused by `group:fga` which represents the group itself as a specific object.

  See: https://openfga.dev/docs/modeling/building-blocks/usersets#what-is-a-userset
  """

  use Protobuf,
    full_name: "openfga.v1.UsersetUser",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :type, 1, type: :string, deprecated: false
  field :id, 2, type: :string, deprecated: false
  field :relation, 3, type: :string, deprecated: false
end

defmodule Openfga.V1.RelationshipCondition do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.RelationshipCondition",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :name, 1, type: :string, deprecated: false
  field :context, 2, type: Google.Protobuf.Struct
end

defmodule Openfga.V1.TupleKeyWithoutCondition do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.TupleKeyWithoutCondition",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :user, 1, type: :string, deprecated: false
  field :relation, 2, type: :string, deprecated: false
  field :object, 3, type: :string, deprecated: false
end

defmodule Openfga.V1.TypedWildcard do
  @moduledoc """
  Type bound public access.

  Normally represented using the `<type>:*` syntax

  `employee:*` represents every object of type `employee`, including those not currently present in the system

  See https://openfga.dev/docs/concepts#what-is-type-bound-public-access
  """

  use Protobuf,
    full_name: "openfga.v1.TypedWildcard",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :type, 1, type: :string, deprecated: false
end

defmodule Openfga.V1.TupleKey do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.TupleKey",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :user, 1, type: :string, deprecated: false
  field :relation, 2, type: :string, deprecated: false
  field :object, 3, type: :string, deprecated: false
  field :condition, 4, type: Openfga.V1.RelationshipCondition
end

defmodule Openfga.V1.Tuple do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Tuple",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :key, 1, type: Openfga.V1.TupleKey, deprecated: false
  field :timestamp, 2, type: Google.Protobuf.Timestamp, deprecated: false
end

defmodule Openfga.V1.TupleKeys do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.TupleKeys",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tuple_keys, 1, repeated: true, type: Openfga.V1.TupleKey, deprecated: false
end

defmodule Openfga.V1.ContextualTupleKeys do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.ContextualTupleKeys",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tuple_keys, 1, repeated: true, type: Openfga.V1.TupleKey, deprecated: false
end

defmodule Openfga.V1.UsersetTree.Leaf do
  @moduledoc """
  A leaf node contains either
  - a set of users (which may be individual users, or usersets
    referencing other relations)
  - a computed node, which is the result of a computed userset
    value in the authorization model
  - a tupleToUserset nodes, containing the result of expanding
    a tupleToUserset value in a authorization model.
  """

  use Protobuf,
    full_name: "openfga.v1.UsersetTree.Leaf",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  oneof(:value, 0)

  field :users, 1, type: Openfga.V1.UsersetTree.Users, oneof: 0
  field :computed, 2, type: Openfga.V1.UsersetTree.Computed, oneof: 0

  field :tuple_to_userset, 3,
    type: Openfga.V1.UsersetTree.TupleToUserset,
    json_name: "tupleToUserset",
    oneof: 0
end

defmodule Openfga.V1.UsersetTree.Nodes do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.UsersetTree.Nodes",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :nodes, 1, repeated: true, type: Openfga.V1.UsersetTree.Node, deprecated: false
end

defmodule Openfga.V1.UsersetTree.Users do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.UsersetTree.Users",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :users, 1, repeated: true, type: :string, deprecated: false
end

defmodule Openfga.V1.UsersetTree.Computed do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.UsersetTree.Computed",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :userset, 1, type: :string, deprecated: false
end

defmodule Openfga.V1.UsersetTree.TupleToUserset do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.UsersetTree.TupleToUserset",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tupleset, 1, type: :string, deprecated: false
  field :computed, 2, repeated: true, type: Openfga.V1.UsersetTree.Computed, deprecated: false
end

defmodule Openfga.V1.UsersetTree.Difference do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.UsersetTree.Difference",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :base, 1, type: Openfga.V1.UsersetTree.Node, deprecated: false
  field :subtract, 2, type: Openfga.V1.UsersetTree.Node, deprecated: false
end

defmodule Openfga.V1.UsersetTree.Node do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.UsersetTree.Node",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  alias Openfga.V1.UsersetTree.Nodes

  oneof(:value, 0)

  field :name, 1, type: :string, deprecated: false
  field :leaf, 2, type: Openfga.V1.UsersetTree.Leaf, oneof: 0
  field :difference, 5, type: Openfga.V1.UsersetTree.Difference, oneof: 0
  field :union, 6, type: Nodes, oneof: 0
  field :intersection, 7, type: Nodes, oneof: 0
end

defmodule Openfga.V1.UsersetTree do
  @moduledoc """
  A UsersetTree contains the result of an Expansion.
  """

  use Protobuf,
    full_name: "openfga.v1.UsersetTree",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :root, 1, type: Openfga.V1.UsersetTree.Node
end

defmodule Openfga.V1.TupleChange do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.TupleChange",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :tuple_key, 1, type: Openfga.V1.TupleKey, deprecated: false
  field :operation, 2, type: Openfga.V1.TupleOperation, enum: true, deprecated: false
  field :timestamp, 3, type: Google.Protobuf.Timestamp, deprecated: false
end

defmodule Openfga.V1.Store do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.Store",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  alias Google.Protobuf.Timestamp

  field :id, 1, type: :string, deprecated: false
  field :name, 2, type: :string, deprecated: false
  field :created_at, 3, type: Timestamp, deprecated: false
  field :updated_at, 4, type: Timestamp, deprecated: false
  field :deleted_at, 5, type: Timestamp
end

defmodule Openfga.V1.UserTypeFilter do
  @moduledoc false
  use Protobuf,
    full_name: "openfga.v1.UserTypeFilter",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :type, 1, type: :string, deprecated: false
  field :relation, 2, type: :string, deprecated: false
end
