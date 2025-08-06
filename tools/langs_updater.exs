#!/usr/bin/env elixir
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

# This script uses Mix.install to pull in the Jason library for JSON handling.
Mix.install([{:jason, "~> 1.2"}])

defmodule LangsUpdater do
  @moduledoc """
  Updates language JSON files to match the master English translations file (en.json).

  For each language file (other than en.json):
    - Missing translation IDs are added with the English default message.
    - Translation IDs not found in en.json are removed.
    - For translation IDs that exist but lack a "defaultMessage", the English default message is added.
    - The output JSON keys are written in the exact same order as in en.json.

  ## Usage

  To use this script, run it from the command line with the directory containing the JSON files as an argument:

      elixir langs_updater.exs <directory_with_json_files>

  If no argument is provided, it defaults to: "../frontend/src/i18n/langs"
  """

  @doc """
  Expects zero or one command-line argument: the directory containing the JSON files.
  """
  def main(args) do
    case args do
      [dir] ->
        process_directory(dir)

      [] ->
        process_directory("../frontend/src/i18n/langs")

      _ ->
        IO.puts("Usage: elixir langs_updater.exs <directory_with_json_files>")
    end
  end

  # Processes the directory by reading en.json and then updating every other JSON file.
  defp process_directory(dir) do
    en_path = Path.join(dir, "en.json")

    if File.exists?(en_path) do
      IO.puts("Loading master English file: #{en_path}")

      # Extract ordered keys from en.json by reading the file as text.
      ordered_keys = extract_keys(en_path)
      en_map = load_json(en_path)

      # Process each language file (all .json files except en.json)
      File.ls!(dir)
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.reject(&(&1 == "en.json"))
      |> Enum.each(fn filename ->
        lang_path = Path.join(dir, filename)
        IO.puts("\nProcessing #{filename}...")
        lang_map = load_json(lang_path)
        update_language_file(lang_path, en_map, lang_map, ordered_keys)
      end)
    else
      IO.puts("Error: en.json not found in directory #{dir}")
    end
  end

  # Loads and decodes a JSON file into a map.
  defp load_json(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, map} ->
            map

          {:error, err} ->
            IO.puts("Error decoding JSON from #{file_path}: #{inspect(err)}")
            %{}
        end

      {:error, err} ->
        IO.puts("Error reading file #{file_path}: #{inspect(err)}")
        %{}
    end
  end

  # Extracts keys in order from the master English JSON file.
  # This reads the file as text and uses a regex to match top-level keys.
  defp extract_keys(file_path) do
    content = File.read!(file_path)
    regex = ~r/"([^"]+)"\s*:\s*\{/
    Regex.scan(regex, content)
    |> Enum.map(fn [_, key] -> key end)
  end

  # Updates a language file so that its keys exactly match those in en.json.
  # For each key from the ordered list:
  #   - If the key exists in the language file:
  #       * Use its value if it contains "defaultMessage".
  #       * Otherwise, add the "defaultMessage" from en.json.
  #   - If missing, the key is added with the English value.
  # The resulting JSON is generated with the desired pretty formatting.
  defp update_language_file(file_path, en_map, lang_map, ordered_keys) do
    # Determine keys added and removed.
    added_keys = ordered_keys -- Map.keys(lang_map)
    removed_keys = Map.keys(lang_map) -- ordered_keys

    if added_keys != [] do
      Enum.each(added_keys, fn key ->
        IO.puts("Added key: #{key}")
      end)
    else
      IO.puts("No keys added.")
    end

    if removed_keys != [] do
      Enum.each(removed_keys, fn key ->
        IO.puts("Removed key: #{key}")
      end)
    else
      IO.puts("No keys removed.")
    end

    # Build an ordered list of key-value tuples.
    ordered_list =
      Enum.map(ordered_keys, fn key ->
        new_value =
          case Map.get(lang_map, key) do
            nil ->
              # Key is missing in the language file; use the English value.
              en_map[key]

            value when is_map(value) ->
              # If "defaultMessage" is missing, merge it in from en.json.
              if Map.has_key?(value, "defaultMessage") do
                value
              else
                Map.put(value, "defaultMessage", en_map[key]["defaultMessage"])
              end

            _ ->
              # Unexpected value type; fall back to English.
              en_map[key]
          end

        {key, new_value}
      end)

    # Generate the JSON string with pretty formatting.
    json_content = encode_ordered_json(ordered_list)
    File.write!(file_path, json_content)
  end

  # Encodes an ordered list of key-value tuples into a JSON string
  # with 2-space indents. Ensures the colon is immediately followed by a space
  # and the opening brace of the value.
  defp encode_ordered_json(ordered_list) do
    entries =
      ordered_list
      |> Enum.map(fn {key, value} ->
        key_str = Jason.encode!(key)
        # Encode the value with pretty formatting.
        value_json = Jason.encode!(value, pretty: true)
        # Indent all lines except the first.
        formatted_value = indent_except_first(value_json, 2)
        "  #{key_str}: #{formatted_value}"
      end)

    "{\n" <> Enum.join(entries, ",\n") <> "\n}\n"
  end

  # Indents all lines of the given text except the first line.
  defp indent_except_first(text, indent) do
    [first | rest] = String.split(text, "\n")
    indented_rest = Enum.map(rest, fn line -> String.duplicate(" ", indent) <> line end)
    Enum.join([first | indented_rest], "\n")
  end
end

LangsUpdater.main(System.argv())
