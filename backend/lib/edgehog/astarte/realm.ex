defmodule Edgehog.Astarte.Realm do
  use Ecto.Schema
  import Ecto.Changeset

  schema "realms" do
    field :name, :string
    field :private_key, :string
    field :cluster_id, :id
    field :tenant_id, :id

    timestamps()
  end

  @doc false
  def changeset(realm, attrs) do
    realm
    |> cast(attrs, [:name, :private_key])
    |> validate_required([:name, :private_key])
  end
end
