defmodule Edgehog.Containers.Network.Deployment do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers.Network

  actions do
    defaults [:read, :destroy, create: [:created], update: [:created]]
  end

  attributes do
    uuid_primary_key :id

    attribute :created, :boolean do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :container, Edgehog.Containers.Network
    belongs_to :device, Edgehog.Devices.Device
  end
end
