defmodule Edgehog.Containers.DeploymentReadyAction do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers

  actions do
    defaults [:read, :destroy]
  end

  attributes do
    uuid_primary_key :id

    attribute :action_type, :atom do
      allow_nil? false
    end
  end

  relationships do
    belongs_to :deployment, Edgehog.Containers.Deployment do
      allow_nil? false
    end

    belongs_to :upgrade_deployment, Edgehog.Containers.DeploymentReadyAction.Upgrade
  end
end
