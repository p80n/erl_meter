defmodule ErlMeter do
  use Application
  use Timex

  import ErlMeter.PostHelper

  alias ErlMeter.Organization
  alias ErlMeter.Infrastructure
  alias ErlMeter.Machine

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

  def main(_args) do
    IO.puts "Starting..."

    Application.load(:tzdata)
    :ok = Application.ensure_started(:tzdata)

    ErlMeter.SamplePoster.start(nil, nil)

    org_count = Application.get_env(:erl_meter, :organizations)
    inf_count = Application.get_env(:erl_meter, :infrastructures)
    machine_count = Application.get_env(:erl_meter, :machines)
    sample_count = Application.get_env(:erl_meter, :samples)

    machines = organization_structs(org_count)
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


#    [ head | _ ] = machines

    # machines
    # |> Enum.map( Agent.start_link&post_sample/1)

    #Agent.start_link( fn -> post_sample(head) end )

    ErlMeter.SamplePoster.serial_post(machines, sample_count)

  end


  def start(_type, args) do
    main(args)
  end


end
