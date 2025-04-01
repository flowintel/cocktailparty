defmodule CocktailpartyWeb.SinkSocket do
  use Phoenix.Socket

  require RemoteIp
  require Logger
  alias Cocktailparty.Accounts

  channel "sink:*", CocktailpartyWeb.SinkChannel

  @impl true
  def connect(%{"token" => token}, socket, connect_info) do
    case Accounts.fetch_user_by_api_token(token) do
      {:ok, user} ->
        remote_ip =
          case RemoteIp.from(connect_info.x_headers) do
            nil -> connect_info.peer_data.address
            # ipv4
            {a, b, c, d} -> {a, b, c, d}
            # ipv6
            {a, b, c, d, e, f, g, h} -> {a, b, c, d, e, f, g, h}
          end

        Logger.metadata(FeedSoket_token: token)
        Logger.metadata(remote_ip: to_string(:inet_parse.ntoa(remote_ip)))
        Logger.metadata(current_user: user.id)
        Logger.info(to_string(:inet_parse.ntoa(remote_ip)))
        {:ok, assign(socket, %{current_user: user.id, remote_ip: remote_ip})}

      :error ->
        :error
    end
  end

  @impl true
  def id(socket), do: "sink:user:#{socket.assigns.current_user}"
end
