defmodule Edgehog.Containers.ReleaseNetworks do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers

  actions do
    defaults [:read, :destroy, create: [], update: []]
  end

  attributes do
    uuid_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :release, Edgehog.Containers.Release do
      primary_key? true
    end

    belongs_to :network, Edgehog.Containers.Network do
      primary_key? true
    end
  end
end
