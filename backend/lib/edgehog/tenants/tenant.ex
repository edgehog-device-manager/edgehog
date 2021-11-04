defmodule Edgehog.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:tenant_id, :id, autogenerate: true}
  schema "tenants" do
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
