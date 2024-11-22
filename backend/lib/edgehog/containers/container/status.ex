defmodule Edgehog.Containers.Container.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:received, :created, :running, :stopped]
end
