import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :argon2_elixir, t_cost: 1, m_cost: 8

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :cocktailparty, Cocktailparty.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "10.106.129.71",
  database: "cocktailparty_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cocktailparty, CocktailpartyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "NFJ/63xQddNJwWPOFw7DKAv4UVoRh6ix22svSVdRsar2Ywan6oGzebh/X5tJG337",
  server: false

# In test we don't send emails.
config :cocktailparty, Cocktailparty.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :cocktailparty,
  redix_uri: "redis://127.0.0.1:6379/0",
  standalone: true,
  broker: true
