defmodule Edgehog.Repo.Migrations.CreateApplianceModels do
  use Ecto.Migration

  def change do
    create table(:appliance_models) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :nothing), null: false

      add :name, :string, null: false
      add :handle, :string, null: false

      add :hardware_type_id,
          references(:hardware_types,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :nothing
          ),
          null: false

      timestamps()
    end

    create index(:appliance_models, [:tenant_id])
    create index(:appliance_models, [:hardware_type_id])
    create unique_index(:appliance_models, [:id, :tenant_id])
    create unique_index(:appliance_models, [:name, :tenant_id])
    create unique_index(:appliance_models, [:handle, :tenant_id])
  end
end
