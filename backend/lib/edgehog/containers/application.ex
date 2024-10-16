defmodule Edgehog.Containers.Application do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read, :destroy, create: [], update: []]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string
    timestamps()
  end

  postgres do
    table "applications"
    repo Edgehog.Repo
  end
end
