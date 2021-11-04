defmodule Edgehog.Repo.Migrations.CreateRealms do
  use Ecto.Migration

  def change do
    create table(:realms) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :private_key, :string, null: false
      add :cluster_id, references(:clusters, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:realms, [:cluster_id])
    create index(:realms, [:tenant_id])
    create unique_index(:realms, [:name, :cluster_id])
    create unique_index(:realms, [:id, :tenant_id])
  end
end
