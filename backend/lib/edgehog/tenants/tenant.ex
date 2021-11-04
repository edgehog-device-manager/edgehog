defmodule Edgehog.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Astarte.Realm

  @primary_key {:tenant_id, :id, autogenerate: true}
  schema "tenants" do
    field :name, :string
    has_one :realm, Realm, foreign_key: :tenant_id

    timestamps()
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
