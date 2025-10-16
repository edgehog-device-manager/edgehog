#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Repo.Migrations.ContainersEnvEnforceShape do
  @moduledoc """
  Changes the `env` column for `Containers.Container` to enforce a key-value
  structure, and migrates all the data to this new format
  """

  use Ecto.Migration

  require Logger

  def up do
    alter table(:containers) do
      # No default value needed because it's not compatible in the
      # transformation, and would need to be dropped anyway
      add :env_new, :map
    end

    # Copy original values, converting NULL to empty object
    execute("UPDATE containers SET env_new = COALESCE(env, '{}'::jsonb)")

    # Create a function for the edit, as nested queries are not allowed in the
    # `USING` clause of `ALTER`. See PostgresQL docs for info about `jsonb_each`,
    # `jsonb_build_object`, `array_agg`
    execute("""
    CREATE OR REPLACE FUNCTION jsonb_obj_to_array(obj jsonb)
    RETURNS jsonb[] AS $$
    BEGIN
      RETURN COALESCE(
        (
          SELECT array_agg(jsonb_build_object('key', key, 'value', value))
          FROM jsonb_each(obj)
        ),
        ARRAY[]::jsonb[]
      );
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """)

    # Alter the table using the created function
    execute("""
      ALTER TABLE containers
      ALTER COLUMN env_new TYPE jsonb[]
      USING (
        jsonb_obj_to_array(env_new)
      )
    """)

    # Add default value adapted to the new type and set not null constraint
    execute("ALTER TABLE containers ALTER COLUMN env_new SET DEFAULT ARRAY[]::jsonb[]")
    execute("ALTER TABLE containers ALTER COLUMN env_new SET NOT NULL")

    execute("DROP FUNCTION jsonb_obj_to_array(jsonb)")

    # Remove previous column and rename the newly created one
    alter table(:containers) do
      remove :env
    end

    rename table(:containers), :env_new, to: :env
  end

  def down do
    alter table(:containers) do
      # No default value needed because it's not compatible in the
      # transformation, and would need to be dropped anyway
      add :env_old, {:array, :map}
    end

    # Copy original values
    execute("UPDATE containers SET env_old = env")

    # Create a function for the edit, as nested queries are not allowed in the
    # `USING` clause of `ALTER`. See PostgresQL docs for info about `jsonb_each`,
    # `jsonb_build_object`. This function loops all the entries of the array
    # and updates the result object by adding the key-value pairs, extracting
    # the key-value to an actual JSON key and value
    execute("""
    CREATE OR REPLACE FUNCTION jsonb_array_to_obj(arr jsonb[])
    RETURNS jsonb AS $$
    DECLARE
      result jsonb := '{}'::jsonb;
      elem jsonb;
    BEGIN
      IF arr IS NULL THEN
        RETURN '{}'::jsonb;
      END IF;

      FOREACH elem IN ARRAY arr
      LOOP
        result := result || jsonb_build_object(elem->>'key', elem->'value');
      END LOOP;
      RETURN result;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """)

    # Alter the table using the created function
    execute("""
    ALTER TABLE containers
    ALTER COLUMN env_old TYPE jsonb
    USING jsonb_array_to_obj(env_old)
    """)

    # Add default value adapted to the new type
    execute("ALTER TABLE containers ALTER COLUMN env_old SET DEFAULT '{}'::jsonb")

    # Drop NOT NULL constraint to restore original column state
    execute("ALTER TABLE containers ALTER COLUMN env_old DROP NOT NULL")

    execute("DROP FUNCTION jsonb_array_to_obj(jsonb[])")

    # Remove previous column and rename the newly created one
    alter table(:containers) do
      remove :env
    end

    rename table(:containers), :env_old, to: :env
  end
end
