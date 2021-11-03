defmodule Edgehog.TenantsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.Tenants` context.
  """

  @doc """
  Generate a tenant.
  """
  def tenant_fixture(attrs \\ %{}) do
    {:ok, tenant} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> Edgehog.Tenants.create_tenant()

    tenant
  end
end
