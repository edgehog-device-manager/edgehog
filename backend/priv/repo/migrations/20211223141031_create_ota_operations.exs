defmodule Edgehog.Repo.Migrations.CreateOtaOperations do
  use Ecto.Migration

  def change do
    create unique_index(:devices, [:id, :tenant_id])

    create table(:ota_operations, primary_key: false) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :id, :binary_id, primary_key: true
      add :base_image_url, :string, null: false
      add :status, :string, default: "Pending", null: false
      add :status_code, :string

      add :device_id,
          references(:devices, with: [tenant_id: :tenant_id], match: :full, on_delete: :nothing),
          null: false

      timestamps()
    end

    create index(:ota_operations, [:tenant_id])
    create index(:ota_operations, [:device_id])
  end
end
