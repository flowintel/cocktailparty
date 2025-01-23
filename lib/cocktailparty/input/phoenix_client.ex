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
    subscribers = Map.get(socket.assigns.subscribing, destination, MapSet.new())
    new_subsribers = MapSet.put(subscribers, name)
    new_subscribing = Map.put(socket.assigns.subscribing, destination, new_subsribers)

    if MapSet.size(subscribers) == 0 do
      join(socket, destination)
    end

    # TODO this is failing for some reason
    {:noreply, update(socket, :subscribing, new_subscribing)}
  end

  @impl Slipstream
  def handle_join(topic, join_response, socket) do
    dbg(socket)
    Logger.info(topic <> " " <> join_response)

    {:ok, socket}
  end

  # @impl Slipstream
  # def handle_connect(socket) do
  #   {:ok, join(socket, @topic)}

  @impl Slipstream
  def handle_message(topic, event, message, socket) do
    # Here we will push to subscribed sources
    Logger.info(inspect({topic, event, message}))

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
