defmodule EdgehogWeb.Router do
  use EdgehogWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", EdgehogWeb do
    pipe_through :api
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
