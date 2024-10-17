defmodule Edgehog.Containers.Deployment do
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

    timestamps()
  end

  relationships do
    belongs_to :device, Edgehog.Devices.Device
    belongs_to :release, Edgehog.Containers.Release
  end

  postgres do
    table "deployments"
    repo Edgehog.Repo
  end
end
