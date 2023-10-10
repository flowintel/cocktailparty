defmodule CocktailpartyWeb.FeedChannelTest do
  use CocktailpartyWeb.ChannelCase

  import Cocktailparty.CatalogFixtures
  import Cocktailparty.UserManagementFixtures
  import Cocktailparty.Catalog
  import Cocktailparty.UserManagement

  setup do
    user = user_fixture()
    update_user(user, %{role: "user"})

    source = source_fixture()
    _ = subscribe(source.id, user.id)

    channel_id = "feed:" <> Integer.to_string(source.id)

    {:ok, _, socket} =
      CocktailpartyWeb.FeedSocket
      |> socket("user_id", %{current_user: user.id, remote_ip: "127.0.0.1"})
      |> subscribe_and_join(CocktailpartyWeb.FeedChannel, channel_id)

    %{socket: socket, channel_id: channel_id}
  end

  test "get presence after_join broadcast", %{} do
    assert_broadcast "presence_diff", %{joins: %{}}
  end

  test "check that info received on the pubsub is relayed to the clients", %{
    channel_id: channel_id
  } do
    payload = "this is a test"
    message = %{channel: channel_id, payload: payload}

    :ok =
      Phoenix.PubSub.broadcast!(
        Cocktailparty.PubSub,
        channel_id,
        message
      )

    assert_push ^channel_id, %{body: ^payload}
  end
end
