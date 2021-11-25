defmodule Edgehog.Repo.Migrations.CreateApplianceModelDescriptions do
  use Ecto.Migration

  def change do
    create table(:appliance_model_descriptions) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :locale, :string, null: false
      add :text, :text, null: false

      add :appliance_model_id,
          references(:appliance_models,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :delete_all
          ),
          null: false

      timestamps()
    end

    create index(:appliance_model_descriptions, [:appliance_model_id])
    create index(:appliance_model_descriptions, [:tenant_id])
    create unique_index(:appliance_model_descriptions, [:locale, :appliance_model_id, :tenant_id])
  end
end
