defmodule Edgehog.Repo.Migrations.AddPictureToApplianceModels do
  use Ecto.Migration

  def change do
    alter table(:appliance_models) do
      add :picture_url, :string
    end
  end
end
