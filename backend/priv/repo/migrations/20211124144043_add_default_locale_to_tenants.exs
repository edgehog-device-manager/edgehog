defmodule Edgehog.Repo.Migrations.AddDefaultLocaleToTenants do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :default_locale, :string, default: "en-US", null: false
    end
  end
end
