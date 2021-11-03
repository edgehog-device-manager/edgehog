defmodule Edgehog.Astarte.Device do
  use Ecto.Schema
  import Ecto.Changeset

  schema "devices" do
    field :device_id, :string
    field :name, :string
    field :realm_id, :id
    field :tenant_id, :id

    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:name, :device_id])
    |> validate_required([:name, :device_id])
  end
end
