defmodule EdgehogWeb.Schema do
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern
  import_types EdgehogWeb.Schema.AstarteTypes

  alias EdgehogWeb.Resolvers

  node interface do
    resolve_type fn
      %Edgehog.Astarte.Device{}, _ ->
        :device

      _, _ ->
        nil
    end
  end

  query do
    node field do
      resolve fn
        %{type: :device, id: id}, _ ->
          Resolvers.Astarte.find_device(%{id: id}, %{})
      end
    end

    import_fields :astarte_queries
  end
end
