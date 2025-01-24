defmodule Cocktailparty.Input.PhoenixClient do
  require Logger

  use Slipstream,
    restart: :temporary

  def start_link(opts) do
    # :name should not be in the options when slipstream validate the options
    name = Keyword.get(opts, :name, __MODULE__)
    Slipstream.start_link(__MODULE__, Keyword.delete(opts, :name), name: name)
  end

  @impl Slipstream
  def init(opts) do
    socket =
      opts
      |> connect!()
      |> assign(:subscriptions, %{})
      |> assign(:subscribing, %{})

    {:ok, socket}
  end

  # @impl Slipstream
  # def handle_connect(socket) do
  #   socket =
  #     socket.assigns.topics
  #     |> Enum.reduce(socket, fn topic, socket ->
  #       case rejoin(socket, topic) do
  #         {:ok, socket} -> socket
  #         {:error, _reason} -> socket
  #       end
  #     end)

  #   {:ok, socket}
  # end

  @impl Slipstream
  def handle_cast({:subscribe, destination, name = {:source, _srcid}}, socket) do
    subscribers = Map.get(socket.assigns.subscriptions, destination, MapSet.new())
    subscribers_subscribing = Map.get(socket.assigns.subscribing, destination, MapSet.new())
    new_subsribers = MapSet.put(subscribers, name)
    new_subscribers_subscribing = MapSet.put(subscribers_subscribing, name)

    socket =
      case joined?(socket, destination) do
        true ->
          socket |> update(:subscriptions, &Map.put(&1, destination, new_subsribers))

        false ->
          socket
          |> update(:subscribing, &Map.put(&1, destination, new_subscribers_subscribing))
          |> join(destination)
      end

    {:noreply, socket}
  end

  @impl Slipstream
  def handle_join(destination, join_response, socket) do
    Logger.info("#{destination} #{inspect(join_response)}")

    # we move from subscribing to subscriptions
    subscribers = Map.get(socket.assigns.subscriptions, destination, MapSet.new())
    subscribers_subscribing = Map.get(socket.assigns.subscribing, destination, MapSet.new())

    socket =
      socket
      |> update(
        :subscriptions,
        &Map.put(&1, destination, MapSet.union(subscribers, subscribers_subscribing))
      )
      |> update(:subscribing, &Map.put(&1, destination, MapSet.new()))

    {:ok, socket}
  end

  @impl Slipstream
  def handle_message(destination, event, message, socket) do
    # Here we will push to subscribed sources
    Logger.info("Got message on #{destination}/#{event}: #{inspect(message)}")

    subscribers = Map.get(socket.assigns.subscriptions, destination, MapSet.new())

    Enum.each(subscribers, fn name ->
      case :global.whereis_name(name) do
        :undefined ->
          {:source, n} = name
          Logger.error("Cannot find process #{n}")

        pid ->
          send(pid, {:new_phoenix_message, message})
      end
    end)

    {:ok, socket}
  end

  @impl Slipstream
  def handle_disconnect(_reason, socket) do
    case reconnect(socket) do
      {:ok, socket} -> {:ok, socket}
      {:error, reason} -> {:stop, reason, socket}
    end
  end
end
