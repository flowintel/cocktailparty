defmodule CocktailpartyWeb.SinkChannel do
  use CocktailpartyWeb, :channel
  alias CocktailpartyWeb.Presence

  require Logger

  alias Cocktailparty.UserManagement

  @minimim_role "user"

  @impl true
  def join("sink:lobby", _payload, socket) do
    {:ok, socket}
  end

  def join("sink:" <> feed_id, _params, socket = %{assigns: %{current_user: user_id}}) do
    if authorized?(feed_id, user_id) do
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
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

  # Presence tracking
  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.current_user, %{
        online_at: inspect(System.system_time(:second)),
        current_ip: inspect(socket)
      })

    {:noreply, socket}
  end

  # intercept presence_diff
  intercept(["presence_diff"])

  @impl true
  def handle_out("presence_diff", _msg, socket) do
    {:noreply, socket}
  end

  # Check whether a user is authorized to push into a feed
  defp authorized?(feed_id, user_id) do
    Logger.info(
      "Checking authorization for UserID: #{user_id} to push into @ SinkId: #{feed_id}."
    )

    UserManagement.is_allowed?(user_id, @minimim_role)
  end
end