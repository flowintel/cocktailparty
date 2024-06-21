defmodule Cocktailparty.Repo.Migrations.RedisDecouplingIndexes do
  use Ecto.Migration

  def change do
    drop unique_index(:redisinstances, [:name])
    execute "ALTER TABLE sinks DROP CONSTRAINT sinks_redis_instance_id_fkey"
    execute "ALTER TABLE sources DROP CONSTRAINT sources_redis_instance_id_fkey"
    execute "ALTER INDEX redisinstances_pkey RENAME TO connections_pkey"
  end
end
