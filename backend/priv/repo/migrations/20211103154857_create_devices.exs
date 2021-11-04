defmodule Edgehog.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :name, :string, null: false
      add :device_id, :string, null: false

      add :realm_id,
          references(:realms, with: [tenant_id: :tenant_id], match: :full, on_delete: :nothing),
          null: false

      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create index(:devices, [:realm_id])
    create index(:devices, [:tenant_id])
  end
end
