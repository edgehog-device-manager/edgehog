defmodule Edgehog.Astarte.Device.WiFiScanResult do
  @enforce_keys [:timestamp]
  defstruct [
    :channel,
    :essid,
    :mac_address,
    :rssi,
    :timestamp
  ]

  @type t() :: %__MODULE__{
          channel: integer() | nil,
          essid: String.t() | nil,
          mac_address: String.t() | nil,
          rssi: integer() | nil,
          timestamp: DateTime.t()
        }

  @behaviour Edgehog.Astarte.Device.WiFiScanResult.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.WiFiScanResult

  @interface "io.edgehog.devicemanager.WiFiScanResults"

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface) do
      wifi_scan_results =
        data["ap"]
        |> Enum.map(fn ap ->
          %WiFiScanResult{
            channel: ap["channel"],
            essid: ap["essid"],
            mac_address: ap["macAddress"],
            rssi: ap["rssi"],
            timestamp: parse_datetime(ap["timestamp"])
          }
        end)

      {:ok, wifi_scan_results}
    end
  end

  defp parse_datetime(nil) do
    nil
  end

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end
end
