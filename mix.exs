defmodule ErlMeter.Mixfile do
  use Mix.Project

  def project do
    [app: :erl_meter,
     mod:  {ErlMeter, []},
     escript: [main_module: ErlMeter],
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps() ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [ applications: [:logger, :httpoison, :timex]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [ {:httpoison, "~> 0.8.0"},
      {:poison, "~> 2.0"},
      {:tzdata, "== 0.1.8", override: true},
      {:timex, "~> 3.1"},
      {:parallel, github: "eproxus/parallel" }
    ]
  end

end
