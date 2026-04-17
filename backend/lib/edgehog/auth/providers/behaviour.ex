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

defmodule Edgehog.Auth.Providers.Behaviour do
  @moduledoc """
  Authz provider behavior.
  """

  @type context() :: term()
  @type fga_tuple() :: {subj :: String.t(), rel :: String.t(), obj :: String.t()}
  @type fga_access_tuple() :: {subj :: String.t(), rel :: String.t(), type :: String.t()}
  @type objects() :: %{objects: term()}
  @type obj_stream() :: term()

  @doc """
  The context initialization function. The context can carry useful information for subsequent actions.
  For example: for OpenFGA's gRPC connections you might want to store here the channel, store_id and model_id.
  """
  @callback init_context(args :: Keyword.t()) :: {:ok, context()} | {:error, term()}

  @doc """
  A check call checks a tuple against the provider

  - subj :: is some id of the person making the request, ideally a OpenID Connect UUID
  - rel  :: is the requested access to the resource (object) in order to perform the action
  - obj  :: is the resource the request is requiring access to

  The context is also provided.

  The check can return
  - :ok             :: meaning that the subject has the right permission to access the resource
  - :notok          :: meaning that the subject has not the right permission to access the resource
  - {:error, error} :: meaning that there was some error in the request.

  For successful returns the new `context` should be provided.
  """
  @callback check(tuple :: fga_tuple(), context :: context()) :: :ok | :notok | {:error, term()}

  @doc """
  A list_objects call lists all objects of the selected type a user has access to.

  - subj :: is some id of the person making the request, ideally a OpenID Connect UUID
  - rel  :: is the requested access to the resource (object) in order to perform the action
  - type :: is the type of resources we want to fetch

  The context should also be provided.

  NOTICE: This creates a list with all the objects! This might be very
  inefficient and possibly stalls the request (e.g. 1mln devices), consider
  using `stream_list_objects`

  The call can return
  - {:ok, objects()} :: meaning that the user has access to the %{objects: list()} list of objects of type `type`
  - {:error, error}  :: meaning that there was some error in the request.

  For successful returns the new `context` should be provided.
  """
  @callback list_objects(tuple :: fga_access_tuple(), context :: context()) ::
              {:ok, objects()} | {:ok, :all} | {:error, term()}

  @doc """
  A stream_list_objects call streams all objects of the selected type a user has access to.

  - subj :: is some id of the person making the request, ideally a OpenID Connect UUID
  - rel  :: is the requested access to the resource (object) in order to perform the action
  - type :: is the type of resources we want to fetch

  The context should also be provided.

  The call can return
  - {:ok, stream(objects())} :: meaning that the user has access to the %{objects: list()} list of objects of type `type`
  - {:error, error}          :: meaning that there was some error in the request.

  For successful returns the new `context` should be provided.
  """
  @callback stream_list_objects(tuple :: fga_access_tuple(), context :: context()) ::
              {:ok, obj_stream()} | {:ok, :all} | {:error, term()}
end
