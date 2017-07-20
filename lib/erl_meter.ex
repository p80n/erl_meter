defmodule ErlMeter do
  use Application
  use Supervisor
  use Timex

  import ErlMeter.PostHelper

  alias ErlMeter.Organization
  alias ErlMeter.Infrastructure
  alias ErlMeter.Machine
  alias ErlMeter.Disk
  alias ErlMeter.Nic
  alias ErlMeter.Sample
  alias ErlMeter.RawSample
  alias ErlMeter.MachineSample
  alias ErlMeter.DiskSample
  alias ErlMeter.NicSample

  def main(_args) do

    set_config_from_environment()

    Application.load(:tzdata)
    :ok = Application.ensure_started(:tzdata)
    threaded = Application.get_env(:erl_meter, :threaded)
    destination = Application.get_env(:erl_meter, :destination)

    run_start = Duration.now
    IO.puts "Starting posts to #{Application.get_env(:erl_meter, :host)}..."
    machines = provision(threaded: threaded)

    sample_start = Duration.now
    post_samples(machines: machines, threaded: threaded, destination: destination)
    run_end = Duration.now

    IO.puts "\nProvisioning took #{Duration.diff(sample_start, run_start, :seconds)} seconds"
    IO.puts "Sample submission took #{Duration.diff(run_end, sample_start, :seconds)} seconds"
    IO.puts "Total time: #{Duration.diff(run_end, run_start, :seconds)} seconds"
    IO.puts "Request rate: #{request_rate(run_start, run_end)} requests/second"
  end

  def request_rate(start_time, end_time) do
    org_count = Application.get_env(:erl_meter, :organizations)
    inf_count = Application.get_env(:erl_meter, :infrastructures)
    machine_count = Application.get_env(:erl_meter, :machines)
    sample_count = Application.get_env(:erl_meter, :samples)

    requests = org_count + (org_count * inf_count) + (org_count * inf_count * machine_count) + sample_count
    total_time = Duration.diff(end_time, start_time, :seconds)

    case total_time do
      0 -> requests
      _ -> round(requests / total_time)
    end

  end

  def organization_structs(count) do
    for n <- 0..count-1, do: %Organization{name: "Sample Organization ##{n+1}", primary_contact: "Contact #{n+1}"}
  end
  def infrastructure_structs(count, organization) do
    for n <- 0..count-1, do: %Infrastructure{organization_id: organization.id, name: "Sample Infrastructure ##{n+1}", status: "active", tags: ["source:erl-meter"] }
  end
  def machine_structs(count, infrastructure) do
    for n <- 0..count-1, do: %Machine{infrastructure_id: infrastructure.id,
                                      organization_id: infrastructure.organization_id,
                                      name: "Sample Machine ##{n+1}",
                                      cpu_count: 2,
                                      status: "poweredOn",
                                      tags: ["source:erl-meter"],
                                      cpu_speed_hz: 2.7e+9,
                                      memory_bytes: 8.0e+9,
                                      disks: [ %Disk{ name: "Sample Disk for machine ##{n+1}",
                                                     status: "active",
                                                     storage_bytes: 1.0e+10 } ],
                                      nics:  [ %Nic{ name: "Sample LAN NIC for machine ##{n+1}",
                                                        status: "connected",
                                                        kind: "LAN" },
                                                  %Nic{ name: "Sample WAN NIC for machine ##{n+1}",
                                                        status: "connected",
                                                        kind: "WAN" } ]
                                     }
  end

  def raw_sample(machine) do
    date_time = Timex.now
    # date_time = [ date.year, date.month, date.day, date.hour, date.minute, date.second ]
    # end_time  = [ date.year, date.month, date.day, date.hour, date.minute + 1, date.second ]
    end_time = Timex.add(date_time, Timex.Duration.from_minutes(1))
    %RawSample{ updated_at: date_time,
                created_at: date_time,
                start: date_time,
                end: end_time,
                type: "Sample",
                org_id: machine.organization_id,
                inf_id: machine.infrastructure_id,
                machine_id: machine.id,
                cpu: 100000,
                memory: 1.074e9,
                disk_io: 1.0e5,
                disk_iops: 2.0e4,
                lan_io: 4.0e5,
                wan_io: 3.0e5,
                storage: 10.0e12,
                consumption: 100 }
  end

  def sample(machine) do
    machine_stats = %MachineSample{ cpu_usage_percent: 50,
                                    memory_bytes: 2.0e+9,
                                    lan_io: 1.0e+9,
                                    wan_io: 1.0e5,
                                    storage: 10.0e+12,
                                    consumption: 100.00 }
    [ disk ] = machine.disks
    disk_stats = %DiskSample{ id: disk.id,
                              usage_bytes: 5.0e+8,
                              read_bytes_per_second: 5000,
                              write_bytes_per_second: 2500 }

    [ lan | [wan] ] = machine.nics
    lan_stats = %NicSample{ id: lan.id,
                            receive_bytes_per_second: 1000,
                            transmit_bytes_per_second: 500 }
    wan_stats = %NicSample{ id: wan.id,
                            receive_bytes_per_second: 500,
                            transmit_bytes_per_second: 1000 }

    %Sample{ machine_id: machine.id,
             start_time: "2016-06-01T10:00:00Z",
             end_time: "2016-06-01T10:05:00Z",
             machine: machine_stats,
             disks: [ disk_stats ],
             nics: [ lan_stats, wan_stats ] }

  end

  def provision(threaded: false) do
    org_count = Application.get_env(:erl_meter, :organizations)
    inf_count = Application.get_env(:erl_meter, :infrastructures)
    machine_count = Application.get_env(:erl_meter, :machines)

    organization_structs(org_count)
    |> Enum.map(fn org -> post("organizations", org) end)
    |> Enum.flat_map(fn org -> infrastructure_structs(inf_count, org) end)
    |> Enum.map(fn inf -> post("organizations/#{inf.organization_id}/infrastructures", inf) end)
    |> Enum.flat_map(fn inf -> machine_structs(machine_count, inf) end)
    |> Enum.map(fn machine -> post("infrastructures/#{machine.infrastructure_id}/machines", machine) end)
  end

  def provision(threaded: true) do
    org_count = Application.get_env(:erl_meter, :organizations)
    inf_count = Application.get_env(:erl_meter, :infrastructures)
    machine_count = Application.get_env(:erl_meter, :machines)

    organization_structs(org_count)
    |> Stream.map(fn org -> post("organizations", org) end)
    |> Stream.flat_map(fn org -> infrastructure_structs(inf_count, org) end)
    |> Stream.map(fn inf -> post("organizations/#{inf.organization_id}/infrastructures", inf) end)
    |> Stream.flat_map(fn inf -> machine_structs(machine_count, inf) end)
    |> Parallel.map(fn machine -> post("infrastructures/#{machine.infrastructure_id}/machines", machine) end, size: 1000)
  end

  def post_samples(machines: machines, threaded: false, destination: :api) do
    sample_count = Application.get_env(:erl_meter, :samples)
    Stream.cycle(machines)
    |> Stream.take(sample_count)
    |> Enum.map(fn machine -> post("machines/#{machine.id}/samples", sample(machine), "on_prem_api_samples" ) end)
  end
  def post_samples(machines: machines, threaded: true, destination: :api) do
    sample_count = Application.get_env(:erl_meter, :samples)
    Stream.cycle(machines)
    |> Stream.take(sample_count)
    |> Parallel.map(fn machine -> post("machines/#{machine.id}/samples", sample(machine), "on_prem_api_samples" ) end, size: 1000)
  end
  def post_samples(machines: machines, threaded: false, destination: :couch) do
    sample_count = Application.get_env(:erl_meter, :samples)
    Stream.cycle(machines)
    |> Stream.take(sample_count)
    |> Enum.map(fn machine -> post("machines/#{machine.id}/samples", raw_sample(machine), "on_prem_api_samples" ) end)
  end
  def post_samples(machines: machines, threaded: true, destination: :couch) do
    sample_count = Application.get_env(:erl_meter, :samples)
    Stream.cycle(machines)
    |> Stream.take(sample_count)
    |> Parallel.map(fn machine -> post("machines/#{machine.id}/samples", raw_sample(machine), "on_prem_api_samples" ) end, size: 1000)
  end


  def init({}) do
  end

  def start(_type, args) do
    main(args)
  end

  def set_config_from_environment() do
    if System.get_env("DESTINATION") do
      Application.put_env(:erl_meter, :destination, String.to_atom(System.get_env("DESTINATION")))
    end
    if System.get_env("HOST") do
      Application.put_env(:erl_meter, :host, System.get_env("HOST"))
    end
    if System.get_env("PORT") do
      Application.put_env(:erl_meter, :port, System.get_env("PORT"))
    end
    if System.get_env("SAMPLES") do
      Application.put_env(:erl_meter, :samples, String.to_integer(System.get_env("SAMPLES")))
    end
    if System.get_env("MACHINES") do
      Application.put_env(:erl_meter, :machines, String.to_integer(System.get_env("MACHINES")))
    end
    if System.get_env("INFRASTRUCTURES") do
      Application.put_env(:erl_meter, :infrastructures, String.to_integer(System.get_env("INFRASTRUCTURES")))
    end
    if System.get_env("ORGANIZATIONS") do
      Application.put_env(:erl_meter, :organizations, String.to_integer(System.get_env("ORGANIZATIONS")))
    end
    if System.get_env("TOKEN") do
      Application.put_env(:erl_meter, :token, System.get_env("TOKEN"))
      IO.puts "Using OAuth token: #{Application.get_env(:erl_meter, :token)}"
    end
    if System.get_env("THREADED") do
      case System.get_env("THREADED") do
        "0"     -> Application.put_env(:erl_meter, :threaded, false)
        "false" -> Application.put_env(:erl_meter, :threaded, false)
        "FALSE" -> Application.put_env(:erl_meter, :threaded, false)
        _       -> Application.put_env(:erl_meter, :threaded, true)
      end
    end

    if Application.get_env(:erl_meter, :host) == "" do
      IO.puts "Please set a HOST"
      System.halt(0)
    end
  end

end
