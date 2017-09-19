# ErlMeter

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add erl_meter to your list of dependencies in `mix.exs`:

        def deps do
          [{:erl_meter, "~> 0.0.1"}]
        end

  2. Ensure erl_meter is started before your application:

        def application do
          [applications: [:erl_meter]]
        end


## Running from docker

```bash
docker run -e DESTINATION=api -e HOST=10.3.0.214 -e SAMPLES=100 -e MACHINES=10000 p80n/erl-meter
```
