defmodule CocktailpartyWeb.SocketTest do
  alias CocktailpartyWeb.FeedSocket
  use CocktailpartyWeb.ChannelCase

  import Cocktailparty.UserManagementFixtures
  import Cocktailparty.UserManagement
  alias Cocktailparty.Accounts

  setup do
    user = user_fixture()
    update_user(user, %{role: "user"})

    %{user: user}
  end

  test "a user can join a channel using a api-token", %{user: user} do
    token = Accounts.create_user_api_token(user)

    connect_info = %{
      peer_data: %{port: 59388, address: {127, 0, 0, 1}, ssl_cert: nil},
      x_headers: []
    }

    assert {:ok, socket} = connect(FeedSocket, %{"token" => token}, connect_info: connect_info)
    assert String.match?(FeedSocket.id(socket), ~r/feed:user:[0-9]*/)
  end

  test "a user cannot join a channel with a invalid token", %{user: user} do
    connect_info = %{
      peer_data: %{port: 59388, address: {127, 0, 0, 1}, ssl_cert: nil},
      x_headers: []
    }

    token = :crypto.strong_rand_bytes(32)

    assert :error = connect(FeedSocket, %{"token" => token}, connect_info: connect_info)
  end
end
