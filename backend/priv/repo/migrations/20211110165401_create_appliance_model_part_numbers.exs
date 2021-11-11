defmodule Edgehog.Repo.Migrations.CreateApplianceModelPartNumbers do
  use Ecto.Migration

  def change do
    create table(:appliance_model_part_numbers) do
      add :part_number, :string
      add :appliance_model_id, references(:appliance_models, on_delete: :nothing)
      add :tenant_id, references(:tenants, on_delete: :nothing)

      timestamps()
    end

    create index(:appliance_model_part_numbers, [:appliance_model_id])
    create index(:appliance_model_part_numbers, [:tenant_id])
  end
end
