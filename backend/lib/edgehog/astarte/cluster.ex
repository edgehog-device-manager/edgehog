defmodule Edgehog.Astarte.Cluster do
  use Ecto.Schema
  import Ecto.Changeset

  schema "clusters" do
    field :base_api_url, :string
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(cluster, attrs) do
    cluster
    |> cast(attrs, [:name, :base_api_url])
    |> validate_required([:name, :base_api_url])
  end
end
