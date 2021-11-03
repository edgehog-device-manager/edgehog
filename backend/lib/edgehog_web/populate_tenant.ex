defmodule EdgehogWeb.PopulateTenant do
  @behaviour Plug

  alias Edgehog.Tenants

  def init(opts), do: opts

  def call(conn, _opts) do
    # TODO: extract tenant from authentication context
    tenant = Tenants.get_tenant!(1)

    _ = Edgehog.Repo.put_tenant_id(tenant.tenant_id)

    Plug.Conn.assign(conn, :current_tenant, tenant)
  end
end
