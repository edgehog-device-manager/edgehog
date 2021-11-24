defmodule Edgehog.Repo.Migrations.CreateApplianceModelDescriptions do
  use Ecto.Migration

  def change do
    create table(:appliance_model_descriptions) do
      add :locale, :string
      add :text, :text
      add :appliance_model_id, references(:appliance_models, on_delete: :nothing)
      add :tenant_id, references(:tenants, on_delete: :nothing)

      timestamps()
    end

    create index(:appliance_model_descriptions, [:appliance_model_id])
    create index(:appliance_model_descriptions, [:tenant_id])
  end
end
