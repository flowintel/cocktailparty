defmodule Cocktailparty.Repo.Migrations.LinkSinksToRedisInstance do
  use Ecto.Migration

  def change do
    alter table(:sinks) do
      add :redis_instance_id, references(:redis_instances, on_delete: :nothing)
    end
  end
end
