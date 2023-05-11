defmodule Cocktailparty.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      CocktailpartyWeb.Telemetry,
      # Start the Ecto repository
      Cocktailparty.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Cocktailparty.PubSub},
      # Start Finch
      {Finch, name: Cocktailparty.Finch},
      # Start the Endpoint (http/https)
      CocktailpartyWeb.Endpoint,
      # Start a worker by calling: Cocktailparty.Worker.start_link(arg)
      # {Cocktailparty.Worker, arg}
      # Redis connection
      {Redix, {Application.get_env(:cocktailparty, :redix_uri), [name: :redix]}},
      # Fun with Flags
      FunWithFlags.Supervisor,
      # Start the Broker once the application is started
      Cocktailparty.Broker
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cocktailparty.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CocktailpartyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
