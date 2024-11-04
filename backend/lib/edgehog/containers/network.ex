defmodule Edgehog.Containers.Network do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read, :destroy, create: []]
  end

  attributes do
    uuid_primary_key :id

    attribute :driver, :string
    attribute :check_duplicate, :boolean
    attribute :internal, :boolean
    attribute :enable_ipv6, :boolean
    timestamps()
  end

  postgres do
    table "networks"
    repo Edgehog.Repo
  end
end
