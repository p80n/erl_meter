defmodule ErlMeter.SamplePoster.Worker do
  use GenServer

  import ErlMeter.PostHelper

  def post_sample(machine, sample_start \\ Date.now) do
    {:ok, sample_end} = sample_start |> Date.shift(minutes: 5) |> Timex.format("{ISO:Extended}")
    {:ok, sample_start} = Timex.format(sample_start, "{ISO:Extended}")
    sample = %ErlMeter.Sample{ start_time: sample_start,
                      end_time: sample_end,
                      machine: %ErlMeter.MachineSample{ cpu_usage_percent: 30, memory_bytes: 2 } }
    post("machines/#{machine.id}/samples", sample)
  end

  def start_link([]) do
    :gen_server.start_link(__MODULE__, [], [])
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(data, _from, state) do
    result = post_sample(data)
    {:reply, [result], state}
  end
end
