defmodule CocktailpartyWeb.FeedChannelTest do
  use CocktailpartyWeb.ChannelCase

  import Cocktailparty.CatalogFixtures
  import Cocktailparty.UserManagementFixtures
  import Cocktailparty.Catalog
  import Cocktailparty.UserManagement

  setup do
    user = user_fixture()

    source = source_fixture()
    _ = subscribe(source.id, user.id)

    channel_id = "feed:" <> Integer.to_string(source.id)

    %{user: user, channel_id: channel_id}
  end

  test "unconfirmed user can not join a channel", %{user: user, channel_id: channel_id} do
    response =
      CocktailpartyWeb.FeedSocket
      |> socket("user_id", %{current_user: user.id, remote_ip: "127.0.0.1"})
      |> subscribe_and_join(CocktailpartyWeb.FeedChannel, channel_id)

    assert response == {:error, %{reason: "unauthorized"}}
  end

  test "confirmed user can join a channel", %{user: user, channel_id: channel_id} do
    update_user(user, %{role: "user"})

    {return, _, socket} =
      CocktailpartyWeb.FeedSocket
      |> socket("user_id", %{current_user: user.id, remote_ip: "127.0.0.1"})
      |> subscribe_and_join(CocktailpartyWeb.FeedChannel, channel_id)

    assert return == :ok
    assert %Phoenix.Socket{} = socket
  end
end
