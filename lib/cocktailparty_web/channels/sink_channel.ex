defmodule CocktailpartyWeb.SinkChannel do
  use CocktailpartyWeb, :channel

  require Logger
  require Redix

  alias Cocktailparty.UserManagement
  alias Cocktailparty.SinkCatalog
  alias Phoenix.Socket.Broadcast

  @impl true
  def join("sink:lobby", _payload, socket) do
    {:ok, socket}
  end

  def join("sink:" <> sink_id, _params, socket = %{assigns: %{current_user: user_id}}) do
    # check which redis_instance we should push into
    sink = SinkCatalog.get_sink(sink_id)

    if sink == nil do
      Logger.error("user #{user_id} refused access to non-existent sink: sink:#{sink_id}")
      {:error, %{reason: "sink not found"}}
    else
      # check authorization
      if authorized?(sink_id, user_id) do
        socket = assign(socket, :sink, sink)
        send(self(), :after_join)
        Logger.info("user #{user_id} connected to sink: sink:#{sink_id}")
        {:ok, socket}
      else
        {:error, %{reason: "unauthorized"}}
      end
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  # TODO find a better verb
  def handle_in("client_push", payload, socket) do
    Logger.info(
      "handling message from #{socket.assigns.current_user} on #{socket.assigns.sink.id}"
    )

    # we push on the pubsub
    broadcast = %Broadcast{
      topic: "sink:" <> Integer.to_string(socket.assigns.sink.id),
      event: :new_client_message,
      payload: payload
    }

    :ok =
      Phoenix.PubSub.broadcast(
        Cocktailparty.PubSub,
        "sink:" <> Integer.to_string(socket.assigns.sink.id),
        broadcast
      )

    {:reply, {:ok, payload}, socket}
  end

  def handle_in("ping", payload, socket) do
    Logger.info(
      "handling ping message from #{socket.assigns.current_user} on #{socket.assigns.sink.id}"
    )

    {:reply, {:ok, payload}, socket}
  end

  def handle_in(_, _, socket) do
    {:reply, {:error, "Unknown command", socket}}
  end

  # don't propagate push message pubblished on the pubsub
  # for pubsubmonitor to be sent to other clients
  [intercept(:new_client_message)]
  @impl true
  def handle_out(:new_client_message, _, socket) do
    {:noreply, socket}
  end

  # Tracker tracking
  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} = CocktailpartyWeb.Tracker.track(socket)
    {:noreply, socket}
  end

  # Check whether a user is authorized to push into a feed
  defp authorized?(sink_id, user_id) do
    Logger.info(
      "Checking authorization for UserID: #{user_id} to push into @ SinkId: #{sink_id}."
    )

    # TODO write access test
    UserManagement.is_confirmed?(user_id) &&
      (UserManagement.can?(user_id, :create_sinks) or UserManagement.can?(user_id, :use_sinks)) &&
      UserManagement.has_access_to_sink?(user_id, sink_id)
  end
end
