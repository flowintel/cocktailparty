defmodule Cocktailparty.UserManagementTest do
  use Cocktailparty.DataCase

  require Logger

  alias Cocktailparty.UserManagement

  describe "users" do
    alias Cocktailparty.UserManagement.User

    import Cocktailparty.UserManagementFixtures

    @invalid_attrs %{}

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert UserManagement.list_users() == [user]
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = UserManagement.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> UserManagement.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = UserManagement.change_user(user)
    end

    test "check whether a user is confimed" do
      user = user_fixture()
      Logger.debug(user)

      assert false == UserManagement.is_confirmed?(user.id)
    end
  end
end
