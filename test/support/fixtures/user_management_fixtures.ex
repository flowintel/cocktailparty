defmodule Cocktailparty.UserManagementFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Cocktailparty.UserManagement` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{})
      |> Cocktailparty.UserManagement.create_user()

    user
  end
end
