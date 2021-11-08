defmodule Edgehog.Repo.Migrations.CreateHardwareTypes do
  use Ecto.Migration

  def change do
    create table(:hardware_types) do
      add :name, :string
      add :handle, :string
      add :tenant_id, references(:tenants, on_delete: :nothing)

      timestamps()
    end

    create index(:hardware_types, [:tenant_id])
  end
end
