defmodule Edgehog.Containers.Release do
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

    attribute :version, :string do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :application, Edgehog.Containers.Application
  end

  postgres do
    table "releases"
    repo Edgehog.Repo
  end
end
