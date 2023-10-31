defmodule CocktailpartyWeb.SinkChannel do
  use CocktailpartyWeb, :channel

  require Logger
  require Redix

  alias Cocktailparty.UserManagement
  alias Cocktailparty.SinkCatalog

  @minimim_role "user"

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
    Logger.info("Handling message from {#socket.assigns.user_id} on #{socket.assigns.sink.id}")
    # push into redis instance corresponding to the sink channel
    # TODO: we could push in phoenix.pubsub to create chatroom
    # get the corresponding redix instance client
    client =
      GenServer.whereis(
        {:global, "redix_" <> Integer.to_string(socket.assigns.sink.redis_instance_id)}
      )

    Redix.command!(client, ["PUBLISH", socket.assigns.sink.channel, payload])
    {:reply, {:ok, payload}, socket}
  end

  # Broadcast messages from the broker to all clients
  # broadcast to everyone in the current topic (room:lobby).
  @impl true
  def handle_info(%{channel: channel, payload: payload}, socket) do
    # hash = :crypto.hash(:sha256, payload) |> Base.encode16()
    # push(socket, channel, %{hash: hash})
    push(socket, channel, %{body: payload})
    {:noreply, socket}
  end

  # Tracker tracking
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
    UserManagement.is_allowed?(user_id, @minimim_role) &&
      UserManagement.has_access_to_sink?(user_id, sink_id)
  end
end
