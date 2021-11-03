defmodule Edgehog.Astarte.Realm do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Astarte.Cluster
  alias Edgehog.Astarte.Device

  schema "realms" do
    field :name, :string
    field :private_key, :string
    field :tenant_id, :id
    belongs_to :cluster, Cluster
    has_many :devices, Device

    timestamps()
  end

  @doc false
  def changeset(realm, attrs) do
    realm
    |> cast(attrs, [:name, :private_key])
    |> validate_required([:name, :private_key])
    |> foreign_key_constraint(:cluster_id)
  end
end
