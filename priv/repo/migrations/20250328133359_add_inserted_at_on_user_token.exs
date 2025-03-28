defmodule Cocktailparty.Repo.Migrations.AddInsertedAtOnUserToken do
  use Ecto.Migration

  def up do
    alter table(:users_tokens) do
      add :last_seen, :utc_datetime_usec
    end
  end

  def down do
    alter(table(:users_tokens)) do
      remove :last_seen
    end
  end
end
