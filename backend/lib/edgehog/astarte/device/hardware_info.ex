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
