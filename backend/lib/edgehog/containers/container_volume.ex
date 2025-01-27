defmodule Edgehog.Containers.ContainerVolume do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read, :destroy, create: [:target]]
  end

  attributes do
    attribute :target, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :container, Edgehog.Containers.Container do
      primary_key? true
      allow_nil? false
    end

    belongs_to :volume, Edgehog.Containers.Volume do
      primary_key? true
      allow_nil? false
    end
  end

  postgres do
    table "container_volumes"
    repo Edgehog.Repo
  end
end
