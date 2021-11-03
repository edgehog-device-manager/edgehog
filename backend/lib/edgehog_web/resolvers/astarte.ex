defmodule EdgehogWeb.Resolvers.Astarte do
  alias Edgehog.Astarte

  def find_device(%{id: id}, _resolution) do
    {:ok, Astarte.get_device!(id)}
  end

  def list_devices(_parent, _args, _context) do
    {:ok, Astarte.list_devices()}
  end
end
