defmodule Cocktailparty.Repo.Migrations.RenameRedisTable do
  use Ecto.Migration

  def change do
    rename table(:redisinstances), to: table(:redis_instances)

    alter table(:sources) do
      remove :redis_instance_id
      add :redis_instance_id, references(:redis_instances, on_delete: :nothing)
    end
  end
end
