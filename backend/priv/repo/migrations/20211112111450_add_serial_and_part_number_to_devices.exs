defmodule Edgehog.Repo.Migrations.AddSerialAndPartNumberToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :serial_number, :string

      add :part_number,
          references(:appliance_model_part_numbers,
            column: :part_number,
            type: :string,
            with: [tenant_id: :tenant_id],
            on_delete: :nothing
          )
    end
  end
end
