defmodule Edgehog.Repo do
  use Ecto.Repo,
    otp_app: :edgehog,
    adapter: Ecto.Adapters.Postgres
end
