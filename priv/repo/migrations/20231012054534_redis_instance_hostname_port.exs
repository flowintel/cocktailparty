defmodule Cocktailparty.Repo.Migrations.RedisInstanceHostnamePort do
  use Ecto.Migration

  def change do
    alter table(:redisinstances) do
      add :hostname, :string, size: 100
      add :port, :integer
      remove :uri
    end
  end
end
