defmodule ErlMeter do
  use Application
  use Timex

  import ErlMeter.PostHelper

  alias ErlMeter.Organization
  alias ErlMeter.Infrastructure
  alias ErlMeter.Machine
  alias ErlMeter.Sample
  alias ErlMeter.MachineSample

  def main(_args) do
    IO.puts "Starting..."

    Application.load(:tzdata)
    :ok = Application.ensure_started(:tzdata)
    threaded = Application.get_env(:erl_meter, :threaded)

    run_start = Time.now
    machines = provision(threaded: threaded)
    sample_start = Time.now
    post_samples(machines: machines, threaded: threaded)
    run_end = Time.now

    IO.puts "\nProvisioning took #{Time.diff(sample_start, run_start, :seconds)} seconds"
    IO.puts "Sample submission took #{Time.diff(run_end, sample_start, :seconds)} seconds"
    IO.puts "Total time: #{Time.diff(run_end, run_start, :seconds)} seconds"
    IO.puts "Request rate: #{request_rate(run_start, run_end)} requests/second"
  end

  def request_rate(start_time, end_time) do
    org_count = Application.get_env(:erl_meter, :organizations)
    inf_count = Application.get_env(:erl_meter, :infrastructures)
    machine_count = Application.get_env(:erl_meter, :machines)
    sample_count = Application.get_env(:erl_meter, :samples)

    requests = org_count * inf_count * machine_count + sample_count
    total_time = Time.diff(end_time, start_time, :seconds)

    Float.round(requests / total_time, 3)

  end

  def organization_structs(count) do
    for n <- 0..count-1, do: %Organization{name: "org#{n+1}", primary_contact: "contact#{n+1}"}
  end
  def infrastructure_structs(count, organization) do
    for n <- 0..count-1, do: %Infrastructure{organization_id: organization.id, name: "inf#{n+1}"}
  end
  def machine_structs(count, infrastructure) do
    for n <- 0..count-1, do: %Machine{infrastructure_id: infrastructure.id,
                                      name: "machine#{n+1}",
                                      cpu_count: 2,
                                      cpu_speed_hz: 2.7e+9,
                                      memory_bytes: 8.0e+9 }
  end

  def sample(machine) do
    machine_stats = %MachineSample{ cpu_usage_percent: 50,
                                    memory_bytes: 2.0e+9 }
    %Sample{ machine_id: machine.id,
             start_time: "2016-06-01T10:00:00Z",
             end_time: "2016-06-01T10:05:00Z",
             machine: machine_stats
             }
  end

  def provision(threaded: false) do
    org_count = Application.get_env(:erl_meter, :organizations)
    inf_count = Application.get_env(:erl_meter, :infrastructures)
    machine_count = Application.get_env(:erl_meter, :machines)

    organization_structs(org_count)
    |> Enum.map(fn org -> post("organizations", org) end)
    |> Enum.map(fn body -> Poison.decode(body, as: %Organization{}) end)
    |> Enum.map(fn response_tuple -> elem(response_tuple, 1) end)
    |> Enum.map(fn org -> infrastructure_structs(inf_count, org) end)
    |> List.flatten
    |> Enum.map(fn inf -> post("organizations/#{inf.organization_id}/infrastructures", inf) end)
    |> Enum.map(fn body -> Poison.decode(body, as: %Infrastructure{}) end)
    |> Enum.map(fn tuple -> elem(tuple, 1) end)
    |> Enum.map(fn inf -> machine_structs(machine_count, inf) end)
    |> List.flatten
    |> Enum.map(fn machine -> post("infrastructures/#{machine.infrastructure_id}/machines", machine) end)
    |> Enum.map(fn body -> Poison.decode(body, as: %Machine{}) end)
    |> Enum.map(fn tuple -> elem(tuple, 1) end)
  end

  def provision(threaded: true) do
    org_count = Application.get_env(:erl_meter, :organizations)
    inf_count = Application.get_env(:erl_meter, :infrastructures)
    machine_count = Application.get_env(:erl_meter, :machines)

    organization_structs(org_count)
    |> Enum.map(fn org -> async_post("organizations", org) end)
    |> Enum.map(fn tasks -> Task.yield(tasks, :infinity) end)
    |> Enum.map(fn {_, res} -> res || nil end)
    |> Enum.map(fn body -> Poison.decode(body, as: %Organization{}) end)
    |> Enum.map(fn response_tuple -> elem(response_tuple, 1) end)
    |> Enum.map(fn org -> infrastructure_structs(inf_count, org) end)
    |> List.flatten
    |> Enum.map(fn inf -> async_post("organizations/#{inf.organization_id}/infrastructures", inf) end)
    |> Enum.map(fn tasks -> Task.yield(tasks, :infinity) end)
    |> Enum.map(fn {_, res} -> res || nil end)
    |> Enum.map(fn body -> Poison.decode(body, as: %Infrastructure{}) end)
    |> Enum.map(fn tuple -> elem(tuple, 1) end)
    |> Enum.map(fn inf -> machine_structs(machine_count, inf) end)
    |> List.flatten
    |> Enum.map(fn machine -> async_post("infrastructures/#{machine.infrastructure_id}/machines", machine) end)
    |> Enum.map(fn tasks -> Task.yield(tasks, :infinity) end)
    |> Enum.map(fn {_, res} -> res || nil end)
    |> Enum.map(fn body -> Poison.decode(body, as: %Machine{}) end)
    |> Enum.map(fn tuple -> elem(tuple, 1) end)
  end

  def post_samples(machines: machines, threaded: true) do
    sample_count = Application.get_env(:erl_meter, :samples)

    Stream.cycle(machines)
    |> Stream.take(sample_count)
    |> Enum.map(fn machine -> async_post("machines/#{machine.id}/samples", sample(machine) ) end)
    |> Enum.map(fn tasks -> Task.yield(tasks, :infinity) end)
  end
  def post_samples(machines: machines, threaded: false) do
    sample_count = Application.get_env(:erl_meter, :samples)

    Stream.cycle(machines)
    |> Stream.take(sample_count)
    |> Enum.map(fn machine -> post("machines/#{machine.id}/samples", sample(machine) ) end)
  end

  def start(_type, args) do
    main(args)
  end


end
