defmodule Cocktailparty.Repo.Migrations.AlterSourcesForRedisinstances do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :redisinstance_id, references(:redisinstances, on_delete: :nothing)
    end
  end
end
