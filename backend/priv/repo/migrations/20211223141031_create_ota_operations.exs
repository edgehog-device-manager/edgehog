defmodule Edgehog.Repo.Migrations.CreateOtaOperations do
  use Ecto.Migration

  def change do
    create table(:ota_operations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :image_url, :string
      add :status, :string
      add :status_code, :string
      add :tenant_id, references(:tenants, on_delete: :nothing, type: :binary_id)
      add :device_id, references(:hardware_type, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:ota_operations, [:tenant_id])
    create index(:ota_operations, [:device_id])
  end
end
