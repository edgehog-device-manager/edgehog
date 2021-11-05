defmodule Edgehog.Repo.Migrations.AddConnectionInfoToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :online, :boolean, default: false, null: false
      add :last_connection, :utc_datetime
      add :last_disconnection, :utc_datetime
    end
  end
end
