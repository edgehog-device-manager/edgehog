defmodule Edgehog.Repo.Migrations.CreateHardwareTypes do
  use Ecto.Migration

  def change do
    create table(:hardware_types) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :handle, :string, null: false

      timestamps()
    end

    create index(:hardware_types, [:tenant_id])
    create unique_index(:hardware_types, [:id, :tenant_id])
    create unique_index(:hardware_types, [:name, :tenant_id])
    create unique_index(:hardware_types, [:handle, :tenant_id])
  end
end
