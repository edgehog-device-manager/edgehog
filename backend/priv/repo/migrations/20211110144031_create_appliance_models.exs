defmodule Edgehog.Repo.Migrations.CreateApplianceModels do
  use Ecto.Migration

  def change do
    create table(:appliance_models) do
      add :name, :string
      add :handle, :string
      add :tenant_id, references(:tenants, on_delete: :nothing)
      add :hardware_type_id, references(:hardware_type, on_delete: :nothing)

      timestamps()
    end

    create index(:appliance_models, [:tenant_id])
    create index(:appliance_models, [:hardware_type_id])
  end
end
