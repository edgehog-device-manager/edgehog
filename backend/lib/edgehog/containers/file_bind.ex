defmodule Edgehog.Containers.FileBind do
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers

  attributes do
    uuid_v7_primary_key :id

    attribute :mountpoint, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :container_deployment, Edgehog.Containers.Container.Deployment do
      allow_nil? false
    end

    belongs_to :file, Edgehog.Files.DeviceFile do
      allow_nil? false
    end
  end
end
