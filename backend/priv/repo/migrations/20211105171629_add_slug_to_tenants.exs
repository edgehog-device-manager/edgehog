defmodule Edgehog.Repo.Migrations.AddSlugToTenants do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :slug, :string, null: false
    end
  end
end
