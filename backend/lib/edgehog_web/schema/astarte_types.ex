defmodule EdgehogWeb.Schema.AstarteTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Resolvers

  node object(:device) do
    field :name, non_null(:string)
    field :device_id, non_null(:string)
  end

  object :astarte_queries do
    @desc "List devices"
    field :devices, non_null(list_of(non_null(:device))) do
      resolve &Resolvers.Astarte.list_devices/3
    end

    @desc "Get a single device"
    field :device, :device do
      arg :id, non_null(:id)
      middleware Absinthe.Relay.Node.ParseIDs, id: :device
      resolve &Resolvers.Astarte.find_device/2
    end
  end
end
