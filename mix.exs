defmodule Cocktailparty.MixProject do
  use Mix.Project

  def project do
    [
      app: :cocktailparty,
      version: "0.3.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        cocktailparty: [
          applications: [
            fun_with_flags: :load,
            fun_with_flags_ui: :load
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Cocktailparty.Application, []},
      extra_applications: extra_applications(Mix.env()) ++ [:logger, :runtime_tools, :os_mon, :public_key]
    ]
  end

  defp extra_applications(:dev), do: [:observer, :wx, :debugger]
  defp extra_applications(_), do: []

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:argon2_elixir, "~> 3.0"},
      {:phoenix, "~> 1.7.20"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:table, ">= 0.0.0"},
      {:myxql, ">= 0.0.0"},
      {:geo, ">= 0.0.0"},
      {:tds, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 0.18.16"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:esbuild, "~> 0.9.0", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.4", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:gen_smtp, "~> 1.1"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:redix, "~>1.5.2"},
      {:remote_ip, "~>1.1.0"},
      # runtime: false because we don't want to start the FunWithFlags.Supervisor automatically
      {:fun_with_flags, "~> 1.12.0", runtime: false},
      {:fun_with_flags_ui, "~> 1.0.0", runtime: false},
      # Libcluster
      {:libcluster, "~> 3.3"},
      {:tzdata, "~> 1.1.2"},
      # STOMP support
      {:barytherium, "~> 0.7.0"},
      # Slipstream to connect to other phoenix nodes
      {:slipstream, "~> 1.1.3"},
      # YAML parsing
      {:yaml_elixir, "~> 2.9.0"},
      # YAML encoding
      {:ymlr, "~> 5.0"},
      # Encryption at rest
      {:cloak_ecto, "~> 1.3.0"},
      {:fresh, "~> 0.4.4"},
      # Certstream
      # {:easy_ssl, "~> 1.3.0"}
      {:easy_ssl, path: "/home/jlouis/Git/EasySSL"},
      # hack around httpoinson issue #494
      {:hackney, "~> 1.21.0"},
      {:httpoison, "~>2.2.2", override: true}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
