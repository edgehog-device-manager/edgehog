defmodule Edgehog.AstarteFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.Astarte` context.
  """

  @doc """
  Generate a cluster.
  """
  def cluster_fixture(attrs \\ %{}) do
    {:ok, cluster} =
      attrs
      |> Enum.into(%{
        base_api_url: "some base_api_url",
        name: "some name"
      })
      |> Edgehog.Astarte.create_cluster()

    cluster
  end

  @doc """
  Generate a realm.
  """
  def realm_fixture(attrs \\ %{}) do
    {:ok, realm} =
      attrs
      |> Enum.into(%{
        name: "some name",
        private_key: "some private_key"
      })
      |> Edgehog.Astarte.create_realm()

    realm
  end
end
