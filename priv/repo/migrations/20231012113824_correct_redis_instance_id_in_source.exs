defmodule Cocktailparty.Repo.Migrations.CorrectRedisInstanceIdInSource do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      remove :redisinstance_id
      add :redis_instance_id, references(:redisinstances, on_delete: :nothing)
    end
  end
end
