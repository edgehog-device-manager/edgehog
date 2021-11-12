defmodule Edgehog.Repo.Migrations.CreateClusters do
  use Ecto.Migration

  def change do
    create table(:clusters) do
      add :name, :string, null: false
      add :base_api_url, :string, null: false

      timestamps()
    end
  end
end
