defmodule Edgehog.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :tenant_id, :bigserial, primary_key: true
      add :name, :string, null: false

      timestamps()
    end
  end
end
