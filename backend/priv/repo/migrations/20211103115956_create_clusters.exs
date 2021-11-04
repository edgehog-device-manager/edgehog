defmodule Edgehog.Repo.Migrations.CreateClusters do
  use Ecto.Migration

  def change do
    create table(:clusters) do
      add :name, :string
      add :base_api_url, :string

      timestamps()
    end
  end
end
