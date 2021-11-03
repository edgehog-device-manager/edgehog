defmodule Edgehog.Repo.Migrations.CreateRealms do
  use Ecto.Migration

  def change do
    create table(:realms) do
      add :name, :string
      add :private_key, :string
      add :cluster_id, references(:clusters, on_delete: :nothing)
      add :tenant_id, references(:tenants, on_delete: :nothing)

      timestamps()
    end

    create index(:realms, [:cluster_id])
    create index(:realms, [:tenant_id])
  end
end
