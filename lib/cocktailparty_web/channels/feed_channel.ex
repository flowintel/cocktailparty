defmodule CocktailpartyWeb.FeedChannel do
  use CocktailpartyWeb, :channel

  require Logger

  alias Cocktailparty.Catalog
  alias Cocktailparty.UserManagement

  @impl true
  def join("feed:lobby", _payload, socket) do
    {:ok, socket}
  end

  def join("feed:" <> feed_id, _params, socket = %{assigns: %{current_user: user_id}}) do
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

  # as messages are broadcasted from the broker, we intercept
  intercept [:new_redis_message, :kick]
  @impl true
  def handle_out(msg, payload, socket) do
    case msg do
      :new_redis_message ->
        push(socket, "new_redis_message", payload)
        {:noreply, socket}

      :kick ->
        Logger.info("KICK")
        push(socket, "kicked", %{})
        {:stop, {:shutdown, :kicked}, socket}
    end
  end

  # Tracker tracking
  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} = CocktailpartyWeb.Tracker.track(socket)
    {:noreply, socket}
  end

  # Check whether a used is authorized to subscribe to a feed
  defp authorized?(feed_id, user_id) do
    Logger.info("Checking authorization for UserID: #{user_id} @ FeedId: #{feed_id}.")
    UserManagement.is_confirmed?(user_id) && Catalog.is_subscribed?(feed_id, user_id)
  end
end
