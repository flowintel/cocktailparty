defmodule Cocktailparty.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :cocktailparty

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def init_roles do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          # Create default role
          repo.insert!(%Cocktailparty.Roles.Role{
            name: "default",
            permissions: %Cocktailparty.Roles.Permissions{
              access_all_sources: false,
              list_all_sources: false,
              create_sinks: false,
              use_sinks: false,
              test: false
            }
          })
        end)
    end
  end

  def init_admin(email) do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          # Create your default admin account
          repo.insert!(%Cocktailparty.Accounts.User{
            is_admin: true,
            email: email,
            hashed_password: Argon2.hash_pwd_salt("passwordtochange"),
            role_id: Cocktailparty.Roles.get_default_role_id!()
          })
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
