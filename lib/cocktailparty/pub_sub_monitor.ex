defmodule Cocktailparty.PubSubMonitor do
  use GenServer
  require Logger

  alias Cocktailparty.SinkCatalog
  alias Cocktailparty.Catalog

  @max_messages 5

  @type queue_map :: %{optional(any()) => :queue.queue(any())}

  @type t :: %__MODULE__{
          q: queue_map()
        }

  defstruct q: %{}

  def start_link(opts \\ []) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(_) do
    Logger.info("PubSubMonitor initializing")
    # we hand over the init process so the supervisor can move on
    {:ok, %{q: Map.new()}, {:continue, :async_init}}
  end

  def handle_continue(:async_init, state) do
    # we subscribe to each topic
    sources = Catalog.list_sources()

    sq =
      Enum.reduce(sources, state.q, fn source, acc ->
        topic = "feed:" <> Integer.to_string(source.id)
        Phoenix.PubSub.subscribe(Cocktailparty.PubSub, topic)
        Map.put(acc, topic, :queue.new())
      end)

    sinks = SinkCatalog.list_sinks()

    sq =
      Enum.reduce(sinks, sq, fn sink, acc ->
        topic = "sink:" <> Integer.to_string(sink.id)
        Phoenix.PubSub.subscribe(Cocktailparty.PubSub, topic)
        Map.put(acc, topic, :queue.new())
      end)

    Logger.info("PubSubMonitor initialized")
    {:noreply, %{q: sq}}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: topic} = broadcast, state) do
    {:ok, tq} = Map.fetch(state.q, topic)

    tq =
      case :queue.len(tq) < @max_messages do
        true ->
          :queue.in(broadcast, tq)

        false ->
          {_, tq} = :queue.out(tq)
          :queue.in(broadcast, tq)
      end

    q = Map.put(state.q, topic, tq)

    {:noreply, %{q: q}}
  end

  def handle_call({:get, topic}, _, state) do
    tq =
      case Map.fetch(state.q, topic) do
        {:ok, tq} ->
          tq

        :error ->
          :queue.new()
      end

    {:reply, :queue.to_list(tq), state}
  end

  def handle_call(_, _, state) do
    {:reply, :error, state}
  end

  def handle_cast({:subscribe, topic}, state) do
    Phoenix.PubSub.subscribe(Cocktailparty.PubSub, topic)
    q = Map.put(state.q, topic, :queue.new())
    Logger.info("PubSubMonitor: subscribing to #{topic}")
    {:noreply, %{q: q}}
  end

  def handle_cast({:unsubscribe, topic}, state) do
    Phoenix.PubSub.unsubscribe(Cocktailparty.PubSub, topic)
    q = Map.drop(state.q, [topic])
    Logger.info("PubSubMonitor: unsubscribing from #{topic}")
    {:noreply, %{q: q}}
  end

  def handle_cast(_, _, state) do
    {:reply, :error, state}
  end
end
