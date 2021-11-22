defmodule Edgehog.Astarte.Device.HardwareInfo do
  defstruct [
    :cpu_architecture,
    :cpu_model,
    :cpu_model_name,
    :cpu_vendor,
    :memory_total_bytes
  ]

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.HardwareInfo

  @interface "io.edgehog.devicemanager.HardwareInfo"

  def get(%AppEngine{} = client, device_id) do
    # TODO: right now we request the whole interface at once, so `memory_total_bytes` can't
    # be requested as string (see https://github.com/astarte-platform/astarte/issues/630).
    # Request it as string as soon as that issue is solved.
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_properties_data(client, device_id, @interface) do
      hardware_info = %HardwareInfo{
        cpu_architecture: data["cpu"]["architecture"],
        cpu_model: data["cpu"]["model"],
        cpu_model_name: data["cpu"]["modelName"],
        cpu_vendor: data["cpu"]["vendor"],
        memory_total_bytes: data["mem"]["totalBytes"]
      }

      {:ok, hardware_info}
    end
  end
end
