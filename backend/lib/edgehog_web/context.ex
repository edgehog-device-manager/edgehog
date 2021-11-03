defmodule EdgehogWeb.Context do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp build_context(conn) do
    current_tenant = get_current_tenant(conn)

    %{current_tenant: current_tenant}
  end

  defp get_current_tenant(conn) do
    conn.assigns[:current_tenant]
  end
end
