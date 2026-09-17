defmodule Edgehog.Containers.Container.FileMount.Changes.NormalizeMountpoint do
  @moduledoc false
  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :mountpoint) do
      nil ->
        changeset

      mountpoint ->
        Ash.Changeset.force_change_attribute(changeset, :mountpoint, normalize(mountpoint))
    end
  end

  defp normalize("/"), do: "/"
  defp normalize(mountpoint), do: String.trim_trailing(mountpoint, "/")
end
