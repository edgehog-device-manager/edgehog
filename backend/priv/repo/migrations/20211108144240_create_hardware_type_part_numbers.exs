defmodule Edgehog.Repo.Migrations.CreateHardwareTypePartNumbers do
  use Ecto.Migration

  def change do
    create table(:hardware_type_part_numbers) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :part_number, :string, null: false
      add :hardware_type_id, references(:hardware_types, on_delete: :delete_all)

      timestamps()
    end

    create index(:hardware_type_part_numbers, [:hardware_type_id])
    create index(:hardware_type_part_numbers, [:tenant_id])
    create unique_index(:hardware_type_part_numbers, [:part_number, :tenant_id])
  end
end
