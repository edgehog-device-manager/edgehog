defmodule Edgehog.Containers do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Edgehog.Containers.ContainerVolume
  end
end
