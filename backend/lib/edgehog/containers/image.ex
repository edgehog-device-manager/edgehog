defmodule Edgehog.Containers.Image do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers

  actions do
    defaults [:read, :destroy, create: []]
  end

  attributes do
    uuid_primary_key :id

    attribute :reference, :string do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :credentials, Edgehog.Containers.ImageCredentials
  end
end
