defmodule ErlMeter.MachineSample do

  defstruct [:cpu_usage_percent, :memory_bytes]
end


defmodule ErlMeter.Sample do
  @derive [Poison.Encoder]
  defstruct [:machine_id, :id,
             :start_time, :end_time,
             machine: MachineSample,
            ]

end
