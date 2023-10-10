defmodule Cocktailparty.UserManagementFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Cocktailparty.UserManagement` context.
  """

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
end
