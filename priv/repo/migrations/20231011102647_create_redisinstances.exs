defmodule Cocktailparty.Repo.Migrations.CreateRedisinstances do
  use Ecto.Migration

  def change do
    create table(:redisinstances) do
      add :name, :string
      add :uri, :string
      add :enabled, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:redisinstances, [:uri])
    create unique_index(:redisinstances, [:name])
  end
end
