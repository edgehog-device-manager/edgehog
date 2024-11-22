defmodule Edgehog.Containers.Image.Deployment do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers.Image

  actions do
    defaults [:read, :destroy, create: [:pulled], update: [:pulled]]
  end

  attributes do
    uuid_primary_key :id

    attribute :pulled, :boolean do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :image, Edgehog.Containers.Image
    belongs_to :device, Edgehog.Devices.Device
  end
end
