defmodule Cocktailparty.Repo.Migrations.RedisInstancesOnDeleteAll do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      modify :redis_instance_id, references(:redis_instances, on_delete: :delete_all),
        from: references(:redis_instances, on_delete: :nothing)
    end

    alter table(:sinks) do
      modify :redis_instance_id, references(:redis_instances, on_delete: :delete_all),
        from: references(:redis_instances, on_delete: :nothing)
    end
  end
end
