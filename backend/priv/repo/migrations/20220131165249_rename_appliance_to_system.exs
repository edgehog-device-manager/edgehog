defmodule Edgehog.Repo.Migrations.RenameApplianceToSystem do
  use Ecto.Migration

  def change do
    # Rename for appliance_models
    rename_index(from: [:appliance_models, :tenant_id], to: [:system_models, :tenant_id])

    rename_index(
      from: [:appliance_models, :hardware_type_id],
      to: [:system_models, :hardware_type_id]
    )

    rename_index(
      from: [:appliance_models, :id, :tenant_id],
      to: [:system_models, :id, :tenant_id]
    )

    rename_index(
      from: [:appliance_models, :name, :tenant_id],
      to: [:system_models, :name, :tenant_id]
    )

    rename_index(
      from: [:appliance_models, :handle, :tenant_id],
      to: [:system_models, :handle, :tenant_id]
    )

    rename_pkey(from: :appliance_models, to: :system_models)
    rename_sequence(from: [:appliance_models, :id], to: [:system_models, :id])
    rename(table(:appliance_models), to: table(:system_models))

    rename_fkey(
      table: :system_models,
      from: [:appliance_models, :hardware_type_id],
      to: [:system_models, :hardware_type_id]
    )

    rename_fkey(
      table: :system_models,
      from: [:appliance_models, :tenant_id],
      to: [:system_models, :tenant_id]
    )

    # Rename for appliance_model_part_numbers
    rename_index(
      from: [:appliance_model_part_numbers, :appliance_model_id],
      to: [:system_model_part_numbers, :system_model_id]
    )

    rename table(:appliance_model_part_numbers), :appliance_model_id, to: :system_model_id

    rename_index(
      from: [:appliance_model_part_numbers, :tenant_id],
      to: [:system_model_part_numbers, :tenant_id]
    )

    rename_index(
      from: [:appliance_model_part_numbers, :part_number, :tenant_id],
      to: [:system_model_part_numbers, :part_number, :tenant_id]
    )

    rename_index(
      from: [:appliance_model_part_numbers, :part_number, :id],
      to: [:system_model_part_numbers, :part_number, :id]
    )

    rename_pkey(from: :appliance_model_part_numbers, to: :system_model_part_numbers)

    rename_sequence(
      from: [:appliance_model_part_numbers, :id],
      to: [:system_model_part_numbers, :id]
    )

    rename table(:appliance_model_part_numbers), to: table(:system_model_part_numbers)

    rename_fkey(
      table: :system_model_part_numbers,
      from: [:appliance_model_part_numbers, :appliance_model_id],
      to: [:system_model_part_numbers, :system_model_id]
    )

    rename_fkey(
      table: :system_model_part_numbers,
      from: [:appliance_model_part_numbers, :tenant_id],
      to: [:system_model_part_numbers, :tenant_id]
    )

    # Rename for appliance_model_descriptions
    rename_index(
      from: [:appliance_model_descriptions, :appliance_model_id],
      to: [:system_model_descriptions, :system_model_id]
    )

    rename_index(
      from: [:appliance_model_descriptions, :tenant_id],
      to: [:system_model_descriptions, :tenant_id]
    )

    rename_index(
      from: [:appliance_model_descriptions, :locale, :appliance_model_id, :tenant_id],
      to: [:system_model_descriptions, :locale, :system_model_id, :tenant_id]
    )

    rename_pkey(from: :appliance_model_descriptions, to: :system_model_descriptions)

    rename_sequence(
      from: [:appliance_model_descriptions, :id],
      to: [:system_model_descriptions, :id]
    )

    rename table(:appliance_model_descriptions), to: table(:system_model_descriptions)
    rename table(:system_model_descriptions), :appliance_model_id, to: :system_model_id

    rename_fkey(
      table: :system_model_descriptions,
      from: [:appliance_model_descriptions, :appliance_model_id],
      to: [:system_model_descriptions, :system_model_id]
    )

    rename_fkey(
      table: :system_model_descriptions,
      from: [:appliance_model_descriptions, :tenant_id],
      to: [:system_model_descriptions, :tenant_id]
    )
  end

  defp rename_fkey(table: table, from: from, to: to) when is_list(from) and is_list(to) do
    from_fkey = build_identifier(from, :fkey)
    to_fkey = build_identifier(to, :fkey)
    rename_constraint(table: table, from: from_fkey, to: to_fkey)
  end

  defp rename_pkey(from: from_table, to: to_table) do
    from_pkey = build_identifier(from_table, :pkey)
    to_pkey = build_identifier(to_table, :pkey)
    rename_constraint(table: from_table, from: from_pkey, to: to_pkey)
  end

  defp rename_sequence(from: from, to: to) when is_list(from) and is_list(to) do
    from_seq = build_identifier(from, :seq)
    to_seq = build_identifier(to, :seq)
    rename_sequence(from: from_seq, to: to_seq)
  end

  defp rename_sequence(from: from, to: to) do
    execute(
      "ALTER SEQUENCE #{from} RENAME TO #{to};",
      "ALTER SEQUENCE #{to} RENAME TO #{from};"
    )
  end

  defp rename_index(from: from, to: to) when is_list(from) and is_list(to) do
    from_index = build_identifier(from, :index)
    to_index = build_identifier(to, :index)
    rename_index(from: from_index, to: to_index)
  end

  defp rename_index(from: from, to: to) when is_binary(from) and is_binary(to) do
    execute(
      """
      ALTER INDEX #{from} RENAME TO #{to};
      """,
      """
      ALTER INDEX #{to} RENAME TO #{from};
      """
    )
  end

  defp rename_constraint(table: table, from: from, to: to) do
    execute(
      """
      ALTER TABLE #{table} RENAME CONSTRAINT "#{from}" TO "#{to}";
      """,
      """
      ALTER TABLE #{table} RENAME CONSTRAINT "#{to}" TO "#{from}";
      """
    )
  end

  @max_identifier_length 63
  defp build_identifier(token_or_tokens, ending) do
    (List.wrap(token_or_tokens) ++ List.wrap(ending))
    |> Enum.join("_")
    |> String.slice(0, @max_identifier_length)
  end
end
