defmodule Edgehog.Repo.Migrations.CreateApplianceModelPartNumbers do
  use Ecto.Migration

  def change do
    create table(:appliance_model_part_numbers) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :part_number, :string, null: false
      add :appliance_model_id, references(:appliance_models, on_delete: :delete_all)

      timestamps()
    end

    create index(:appliance_model_part_numbers, [:appliance_model_id])
    create index(:appliance_model_part_numbers, [:tenant_id])
    create unique_index(:appliance_model_part_numbers, [:part_number, :tenant_id])
    create unique_index(:appliance_model_part_numbers, [:part_number, :id])
  end
end
