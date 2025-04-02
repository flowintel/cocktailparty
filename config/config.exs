# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :cocktailparty,
  ecto_repos: [Cocktailparty.Repo]

# Configures the endpoint
config :cocktailparty, CocktailpartyWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: CocktailpartyWeb.ErrorHTML, json: CocktailpartyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Cocktailparty.PubSub,
  live_view: [signing_salt: "YtsMJ/+7"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
# config :cocktailparty, Cocktailparty.Mailer, adapter: Swoosh.Adapters.Local

config :cocktailparty, Cocktailparty.Mailer,
  adapter: Swoosh.Adapters.Sendmail,
  cmd_path: "sendmail"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.17",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Erlang's Logger
config :logger, :default_handler,
  config: [
    file: ~c"logs/cocktailparty.log",
    filesync_repeat_interval: 5000,
    file_check: 5000,
    max_no_bytes: 10_000_000,
    max_no_files: 5,
    compress_on_rotate: true
  ]

# Configures Elixir's Log formatter
config :logger, :default_formatter,
  format: "$node $date $time $level $message $metadata \n",
  metadata: [:request_id, :remote_ip, :websocket_token, :current_user]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Fun With Flags configuration
config :fun_with_flags, :cache,
  enabled: true,
  # in seconds
  ttl: 900

config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: Cocktailparty.Repo

config :fun_with_flags, :cache_bust_notifications,
  enabled: true,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: Cocktailparty.PubSub

config :libcluster,
  debug: true,
  topologies: [
    gossip: [
      strategy: Elixir.Cluster.Strategy.Gossip,
      config: [
        port: 45892,
        if_addr: "0.0.0.0",
        multicast_addr: "255.255.255.255",
        broadcast_only: true,
        secret: "thisismypassword"
      ]
    ]
  ]

# Setting defaults
config :cocktailparty,
  standalone: true,
  broker: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# IP x-fwd-for rewriting config
config :remote_ip, debug: false

# TimeZone data
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :tzdata, :autoupdate, :disabled

config :cocktailparty, Cocktailparty.Accounts.AdminNotifier,
  # The external domain
  instance_baseurl: "localhost:4000",
  instance_name: "CIRCL Cocktailparty",
  instance_email: "info@circl.lu"
