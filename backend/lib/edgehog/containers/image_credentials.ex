defmodule Edgehog.Containers.ImageCredentials do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :username, :string do
      allow_nil? false
    end

    attribute :password, :string do
      sensitive? true
    end

    timestamps()
  end
end
