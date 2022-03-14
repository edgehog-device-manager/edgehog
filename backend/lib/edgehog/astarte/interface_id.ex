defmodule Edgehog.Astarte.InterfaceID do
  @enforce_keys [:name, :major, :minor]
  defstruct @enforce_keys
end
