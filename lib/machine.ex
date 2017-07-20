defmodule ErlMeter.Machine do
  @derive [Poison.Encoder]
  defstruct [ :organization_id, :infrastructure_id, :id,
              :name, :status, :tags,
              :cpu_count, :cpu_speed_hz, :memory_bytes,
              :disks, :nics
            ]

end
