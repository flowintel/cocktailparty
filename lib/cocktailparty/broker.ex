defmodule Cocktailparty.Broker do
  use GenServer
  alias Redix.PubSub

  alias Cocktailparty.Catalog

  defstruct [
    :pubsub,
    subscribed: [%{source: nil, ref: nil}],
    subscribing: [%{source: nil, ref: nil}]
  ]

  require Logger

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, pubsub} = PubSub.start_link(Application.get_env(:cocktailparty, :redix_uri))
    # Get sources from the catalog
    sources = Catalog.list_sources()

    subscribing = Enum.reduce(sources, [], fn source, subscribing ->
      # Subscribe to each source
      Logger.info("Subscribing to #{source.name}")
      {:ok, ref} = PubSub.subscribe(pubsub, "#{source.channel}", self())
      [%{source: source, ref: ref} | subscribing]
    end)

    {:ok, %{subscribing: subscribing, pubsub: pubsub, subscribed: []}}
  end

  def handle_info({:redix_pubsub, _pid, ref, :subscribed, _message}, state) do
    # Find the source that we are subscribing to
    current_sub = Enum.find(state.subscribing, fn subscribing -> subscribing.ref == ref end)
    # Remove the source from the list of sources we are subscribing to
    subscribing = Enum.reject(state.subscribing, fn subscribing -> subscribing.ref == ref end)
    # Add the source to the list of sources we are subscribed to
    subscribed = [%{source: current_sub.source, ref: ref} | state.subscribed]
    # Update the state
    state = %{subscribing: subscribing, subscribed: subscribed, pubsub: state.pubsub}
    # Log the subscription
    Logger.info("Subscribed to #{current_sub.source.name}")
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pid, ref, :disconnected, _message}, state) do
    # Find the source that is disconnecting
    current_sub = Enum.find(state.subscribed, fn subscribed -> subscribed.ref == ref end)
    # Remove the source from the list of sources we are subscribed to
    subscribed = Enum.reject(state.subscribed, fn subscribed -> subscribed.ref == ref end)
    # Add the sources to the list of sources we are subscribing to
    subscribing = [%{source: current_sub.source, ref: ref} | state.subscribing]
    # Update the state
    state = %{subscribing: subscribing, subscribed: subscribed, pubsub: state.pubsub}
    Logger.info("Disconnected from #{inspect(current_sub.source.name)}")
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pid, ref, :message, message}, state) do
    # case ref do
    #   # If the message is from a source we are subscribed to
    #   ref when Enum.any?(state.subscribed, fn subscribed -> subscribed.ref == ref end) ->
    #     # Log the message
    #     Logger.info("Received message from #{inspect(pid)}: #{inspect(message)}")
    #     # Get the source
    #     source = Enum.find(state.subscribing, fn subscribing -> subscribing.ref == ref end)
    #     # Broadcast the message to all clients
    #     :ok = Phoenix.PubSub.broadcast!(state.pubsub, "feed:" <> source.id, message)
    #     {:noreply, state}
    #   # If the message is from a source we are not subscribed to
    #   _ ->
    #     # Log the message
    #     Logger.info("Received message from #{inspect(pid)}: #{inspect(message)}")
    #     {:noreply, state}
    # end

    current_sub = Enum.find(state.subscribed, fn subscribed -> subscribed.ref == ref end)
    :ok = Phoenix.PubSub.broadcast!(Cocktailparty.PubSub, "feed:" <> Integer.to_string(current_sub.source.id), message)
    {:noreply, state}
  end

end
