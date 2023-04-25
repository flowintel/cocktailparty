defmodule Cocktailparty.Broker do
  use GenServer
  alias Redix.PubSub

  require Logger

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, pubsub} = PubSub.start_link(Application.get_env(:cocktailparty, :redix_uri))
    {:ok, ref} = Redix.PubSub.subscribe(pubsub, "dns_collector", self())
    {:ok, %{pubsub: pubsub, ref: ref}}
  end

  def handle_info({:redix_pubsub, _pid, _ref, :subscribed, message}, state) do
    Logger.info("Subscribed to #{inspect(message)}")
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, pid, _ref, :message, message}, state) do
    Logger.info("Received message from #{inspect(pid)}: #{inspect(message)}")
    :ok = Phoenix.PubSub.broadcast!(Cocktailparty.PubSub, "room:lobby", message)
    {:noreply, state}
  end
end
