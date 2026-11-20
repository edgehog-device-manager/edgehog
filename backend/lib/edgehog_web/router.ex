# This file is part of Edgehog.
#
# Copyright 2021-2026 SECO Mind Srl
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

defmodule EdgehogWeb.Router do
  use EdgehogWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EdgehogWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug EdgehogWeb.PopulateTenant
    plug EdgehogWeb.Auth
    plug EdgehogWeb.PopulateActor
    plug AshGraphql.Plug
  end

  pipeline :triggers do
    plug :accepts, ["json"]
    plug EdgehogWeb.PopulateTenant
    plug EdgehogWeb.PopulateActor
  end

  pipeline :admin_api do
    plug :accepts, ["json"]
    plug EdgehogWeb.AdminAPI.Auth
  end

  scope "/admin-api/v1" do
    forward "/swagger",
            OpenApiSpex.Plug.SwaggerUI,
            path: "/admin-api/v1/open_api",
            default_model_expand_depth: 4

    pipe_through :admin_api

    forward "/", EdgehogWeb.AdminAPI
  end

  forward "/graphiql", Absinthe.Plug.GraphiQL,
    schema: EdgehogWeb.Schema,
    interface: :playground,
    socket: EdgehogWeb.GqlSocket

  get "/version", EdgehogWeb.VersionController, :show

  scope "/", EdgehogWeb do
    pipe_through :browser

    get "/", SessionController, :root
    post "/session", SessionController, :create
    get "/session/auto", SessionController, :auto
    post "/session/dev", SessionController, :dev_create
    delete "/session", SessionController, :delete

    live_session :public,
      on_mount: [{EdgehogWeb.LiveAuth, :redirect_if_authenticated}] do
      live "/login", Auth.LoginLive, :index
    end
  end

  scope "/tenants/:tenant_slug" do
    scope "/", EdgehogWeb do
      pipe_through :browser

      live_session :tenant_authenticated,
        on_mount: [{EdgehogWeb.LiveAuth, :require_authenticated}] do
        live "/devices", DevicesLive.Index, :index
      end
    end

    scope "/api" do
      pipe_through :api

      match :*, "/", Absinthe.Plug, schema: EdgehogWeb.Schema
    end

    scope "/triggers", EdgehogWeb do
      pipe_through :triggers

      post "/", AstarteTriggerController, :process_event
    end
  end
end
