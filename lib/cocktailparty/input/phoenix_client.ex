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

  @impl Slipstream
  def handle_connect(socket) do
    socket =
      socket
      |> update(
        :subscriptions,
        &Enum.reduce(&1, %{}, fn destination, acc ->
          acc
          |> Map.put(
            destination,
            MapSet.union(
              socket.assigns.subscriptions[destination],
              socket.assigns.subscribing[destination]
            )
          )
        end)
      )

    socket =
      socket.assigns.subscriptions
      |> Enum.reduce(socket, fn topic, socket ->
        case rejoin(socket, topic) do
          {:ok, socket} -> socket
          {:error, _reason} -> socket
        end
      end)

    {:ok, socket}
  end

  @impl Slipstream
  def handle_cast(
        {:subscribe, %{destination: destination, name: {:source, _srcid} = name}},
        socket
      ) do
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

  # def handle_cast({:unsubscribe, destination, _name = {:source, _srcid}}, socket) do
  def handle_cast({:unsubscribe, %{destination: destination, name: {:source, _srcid}}}, socket) do
    subscribers = Map.get(socket.assigns.subscriptions, destination, MapSet.new())

    socket =
      case joined?(socket, destination) do
        true ->
          # if that was the last subscriber we send leave
          if MapSet.size(subscribers) == 1 do
            socket
            |> leave(destination)
            |> update(:subscriptions, &Map.delete(&1, destination))
          else
            socket
            |> update(:subscriptions, &Map.delete(&1, destination))
          end

        false ->
          # we remove the sub from the set
          socket
          |> update(:subscriptions, &Map.delete(&1, destination))
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
  def handle_message(destination, _event, message, socket) do
    # Here we will push to subscribed sources
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
