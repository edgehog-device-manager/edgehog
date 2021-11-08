defmodule Edgehog.Repo.Migrations.AddUniquenessConstraints do
  use Ecto.Migration

  def change do
    create unique_index(:tenants, [:name])
    create unique_index(:tenants, [:slug])

    create unique_index(:clusters, [:name])

    create unique_index(:realms, [:name, :tenant_id])

    create unique_index(:devices, [:device_id, :realm_id, :tenant_id])
  end
end
