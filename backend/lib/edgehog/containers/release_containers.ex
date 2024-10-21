defmodule Edgehog.Containers.ReleaseContainers do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read, :destroy, create: []]
  end

  attributes do
    timestamps()
  end

  relationships do
    belongs_to :release, Edgehog.Containers.Release do
      primary_key? true
    end

    belongs_to :container, Edgehog.Containers.Container do
      primary_key? true
    end
  end

  postgres do
    table "release_containers"
    repo Edgehog.Repo
  end
end
