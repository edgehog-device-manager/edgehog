defmodule Edgehog.Containers.Types.RestartPolicy do
  @moduledoc false
  use Ash.Type.Enum, values: [nil, :no, :always, :unless_stopped, :on_failure]
end
