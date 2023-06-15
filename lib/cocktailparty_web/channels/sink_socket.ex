defmodule CocktailpartyWeb.SinkSocket do
  use Phoenix.Socket

  channel "feed:*", CocktailpartyWeb.FeedChannel

  @impl true
  def connect(%{"token" => token}, socket, connect_info) do
    # TODO make the salt a config value
    # max_age: 1209600 is equivalent to two weeks in seconds
    case Phoenix.Token.verify(socket, "user socket", token, max_age: 1_209_600) do
      {:ok, user_id} ->
        {:ok, assign(socket, %{current_user: user_id, connect_info: connect_info})}

      {:error, _reason} ->
        :error
    end
  end

  @impl true
  def id(socket), do: "current_user:#{socket.assigns.current_user}"
end
