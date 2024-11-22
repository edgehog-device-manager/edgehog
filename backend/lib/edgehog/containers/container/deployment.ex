defmodule Edgehog.Containers.Container.Deployment do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers.Container

  actions do
    defaults [:read, :destroy, create: [:status], update: [:status]]
  end

  attributes do
    uuid_primary_key :id

    attribute :status, Edgehog.Containers.Container.Status do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :container, Edgehog.Containers.Container
    belongs_to :device, Edgehog.Devices.Device
  end
end
