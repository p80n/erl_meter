defmodule ErlMeter.SamplePoster do
  use Application


  defp pool_name() do
    :sample_pool
  end

  def start(_type, _args) do

    poolboy_config = [
      { :name, {:local, pool_name()} },
      { :worker_module, SamplePoster.Worker },
      { :size, 5 },
      { :max_overflow, 10 }
    ]

    children = [
      :poolboy.child_spec(pool_name(), poolboy_config, [])
    ]

    options = [
      strategy: :one_for_one,
      name: SamplePoster.Supervisor
    ]
IO.puts "here"
Supervisor.start_link(children, options)
IO.puts "there"
  end

  defp doit(machine) do
    :poolboy.transaction(
      pool_name(),
      fn(pid) -> :gen_server.call(pid, machine) end,
      :infinity

    )
  end

  def serial_post(machines, max_samples) do

    [ head | _ ] = machines

    doit(head)

    # Stream.cycle(machines)
    # |> Enum.take(max_samples)
    # |> Enum.map( fn(machine) -> doit(machine) end )
  end


  def parallel_post(machines, max_samples) do
    Stream.cycle(machines)
    |> Enum.take(max_samples)
    |> Enum.map( fn(machine) -> spawn( fn() -> doit(machine) end ) end )

  end

end
