defmodule Edgehog.Containers.ContainerNetwork do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read, :destroy, create: []]
  end

  relationships do
    belongs_to :container, Edgehog.Containers.Container do
      primary_key? true
      allow_nil? false
    end

    belongs_to :network, Edgehog.Containers.Network do
      primary_key? true
      allow_nil? false
    end
  end

  postgres do
    table "container_networks"
    repo Edgehog.Repo
  end
end
