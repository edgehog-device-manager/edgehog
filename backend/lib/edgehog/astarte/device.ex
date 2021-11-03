defmodule Edgehog.Astarte.Device do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Astarte.Realm

  schema "devices" do
    field :device_id, :string
    field :name, :string
    field :tenant_id, :id
    belongs_to :realm, Realm

    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:name, :device_id])
    |> validate_required([:name, :device_id])
  end
end
