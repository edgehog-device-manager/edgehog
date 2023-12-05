#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule EdgehogWeb.Router do
  use EdgehogWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug EdgehogWeb.PopulateTenant
    plug EdgehogWeb.Auth
    plug EdgehogWeb.Context
  end

  pipeline :triggers do
    plug :accepts, ["json"]
    plug EdgehogWeb.PopulateTenant
  end

  pipeline :admin_api do
    plug :accepts, ["json"]
    plug EdgehogWeb.AdminAPI.Auth
  end

  scope "/admin-api/v1", EdgehogWeb.AdminAPI do
    pipe_through :admin_api

    post "/tenants", TenantsController, :create
    delete "/tenants/:tenant_slug", TenantsController, :delete_by_slug
  end

  forward "/graphiql", Absinthe.Plug.GraphiQL, schema: EdgehogWeb.Schema

  scope "/tenants/:tenant_slug" do
    scope "/api" do
      pipe_through :api

      forward "/", Absinthe.Plug, schema: EdgehogWeb.Schema
    end

    scope "/triggers", EdgehogWeb do
      pipe_through :triggers

      post "/", AstarteTriggerController, :process_event
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
