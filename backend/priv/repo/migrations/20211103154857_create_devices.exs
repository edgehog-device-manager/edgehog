defmodule Edgehog.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :name, :string
      add :device_id, :string
      add :realm_id, references(:realms, on_delete: :nothing)
      add :tenant_id, references(:tenants, on_delete: :nothing)

      timestamps()
    end

    create index(:devices, [:realm_id])
    create index(:devices, [:tenant_id])
  end
end
