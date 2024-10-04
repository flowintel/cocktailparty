defmodule Cocktailparty.UserManagementFixtures do
  alias Cocktailparty.Accounts.User

  @moduledoc """
  This module defines test helpers for creating
  entities via the `Cocktailparty.UserManagement` context.
  """
  alias Cocktailparty.Repo

  @doc """
  Generate a user.
  """
  def user_fixture(_ \\ %{}) do
    {:ok, user} =
      Cocktailparty.UserManagement.create_user(%{
        email: "toto@test.com",
        password: "234324SDFdsag sdFGdsfgmypassword",
        is_admin: false,
        role: "uuser"
      })

    user
  end

  @doc """
  Generate an admin user.
  """
  def admin_user_fixture(_ \\ %{}) do
    {:ok, user} =
      Cocktailparty.UserManagement.create_user(%{
        email: "admin@test.com",
        password: "234324SDFdsag sdFGdsfgmypassword",
        is_admin: true
      })

    changeset = User.confirm_changeset(user)

    {:ok, user} = Repo.update(changeset)
    user
  end
end
