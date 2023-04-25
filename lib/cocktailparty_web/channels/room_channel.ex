defmodule CocktailpartyWeb.RoomChannel do
  use CocktailpartyWeb, :channel

  @impl true
  def join("room:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
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
  def handle_info(%{channel: "dns_collector", payload: payload}, socket) do
    broadcast!(socket, "new_msg", %{body: Jason.decode!(payload)})
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
