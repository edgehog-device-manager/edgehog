defmodule Edgehog.Containers.DeploymentReadyAction.Upgrade do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers

  actions do
    defaults [:read, :destroy]
  end
  

  attributes do
    uuid_primary_key :id
  end

  relationships do
    belongs_to :upgrade_target, Edgehog.Containers.Deployment do
      allow_nil? false
    end
  end
end
