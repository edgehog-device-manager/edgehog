defmodule Edgehog.Containers do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Edgehog.Containers.DeploymentReadyAction.Upgrade
    resource Edgehog.Containers.DeploymentReadyAction
  end
end
