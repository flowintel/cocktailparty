defmodule CocktailpartyWeb.FeedChannel do
  use CocktailpartyWeb, :channel

  require Logger

  alias Cocktailparty.Catalog

  @impl true
  def join("feed:lobby", _payload, socket) do
    {:ok, socket}
  end

  def join("feed:" <> feed_id, _params, socket = %{assigns: %{current_user: user_id}}) do
    if authorized?(feed_id, user_id) do
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

  # Add authorization logic here as required.
  defp authorized?(feed_id, user_id) do
    Logger.info("Checking authorization for #{feed_id} and #{user_id}")
    Catalog.is_subscribed?(feed_id, user_id)
  end
end
