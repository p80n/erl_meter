defmodule ErlMeter.MachineSample do

  defstruct [:cpu_usage_percent, :memory_bytes, :disk_io, :lan_io, :wan_io, :storage,
             :consumption ]
end


defmodule ErlMeter.Sample do
  @derive {Poison.Encoder, except: [:id]}
  defstruct [:machine_id, :id,
             :start_time, :end_time,
             :org_id, :inf_id,
             machine: MachineSample,
             type: "Sample"
            ]


end

defmodule ErlMeter.RawSample do
  @derive {Poison.Encoder, except: [:id]}
  defstruct [ :updated_at, :created_at,
              :start, :end,
              :org_id, :inf_id, :machine_id,
              :cpu, :memory,
              :disk_io, :lan_io, :wan_io,
              :storage, :consumption,
              :type
            ]

end
