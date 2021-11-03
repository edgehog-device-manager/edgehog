defmodule EdgehogWeb.Router do
  use EdgehogWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug EdgehogWeb.PopulateTenant
    plug EdgehogWeb.Context
  end

  scope "/api" do
    pipe_through :api

    forward "/graphiql", Absinthe.Plug.GraphiQL, schema: EdgehogWeb.Schema

    forward "/", Absinthe.Plug, schema: EdgehogWeb.Schema
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
