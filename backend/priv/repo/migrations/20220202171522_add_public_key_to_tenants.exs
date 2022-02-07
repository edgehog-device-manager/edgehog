defmodule Edgehog.Repo.Migrations.AddPublicKeyToTenants do
  use Ecto.Migration

  def up do
    # Add an empty string as default and then remove it so we handle existing tenants.
    # A real public key must be added afterwards manually.
    alter table(:tenants) do
      add :public_key, :text, null: false, default: ""
    end

    alter table(:tenants) do
      modify :public_key, :text, null: false, default: nil
    end
  end

  def down do
    alter table(:tenants) do
      remove :public_key
    end
  end
end
