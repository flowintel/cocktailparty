defmodule CocktailpartyWeb.SinkSocket do
  use Phoenix.Socket

  require RemoteIp
  require Logger

  channel "feed:*", CocktailpartyWeb.FeedChannel

  @impl true
  def connect(%{"token" => token}, socket, connect_info) do
    # TODO make the salt a config value
    # max_age: 1209600 is equivalent to two weeks in seconds
    case Phoenix.Token.verify(socket, "user socket", token, max_age: 1_209_600) do
      {:ok, user_id} ->
        remote_ip =
          case  RemoteIp.from(connect_info.x_headers) do
            nil -> connect_info.peer_data.address
            {a,b,c,d} -> {a, b, c, d}
        end
        Logger.metadata(websocket_token: token)
        Logger.metadata(remote_ip: to_string(:inet_parse.ntoa(remote_ip)))
        Logger.metadata(current_user: user_id)
        Logger.info(to_string(:inet_parse.ntoa(remote_ip)))
        {:ok, assign(socket, %{current_user: user_id, remote_ip: remote_ip})}

      {:error, _reason} ->
        :error
    end
  end

  @impl true
  def id(socket), do: "current_user:#{socket.assigns.current_user}"

end
