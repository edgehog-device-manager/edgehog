defmodule Edgehog.Repo.Migrations.CreateHardwareTypePartNumbers do
  use Ecto.Migration

  def change do
    create table(:hardware_type_part_numbers) do
      add :part_number, :string
      add :hardware_type_id, references(:hardware_types, on_delete: :nothing)
      add :tenant_id, references(:tenants, on_delete: :nothing)

      timestamps()
    end

    create index(:hardware_type_part_numbers, [:hardware_type_id])
    create index(:hardware_type_part_numbers, [:tenant_id])
  end
end
