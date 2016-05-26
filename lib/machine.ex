defmodule ErlMeter.Machine do
  @derive {Poison.Encoder, except: [:id]}
  defstruct [:infrastructure_id, :id, :name,
             :cpu_count, :cpu_speed_hz, :memory_bytes
            ]

end
