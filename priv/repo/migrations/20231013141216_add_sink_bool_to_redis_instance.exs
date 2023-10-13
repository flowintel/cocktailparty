defmodule Cocktailparty.Repo.Migrations.AddSinkBoolToRedisInstance do
  use Ecto.Migration

  def change do
    alter table(:redis_instances) do
      add :sink, :boolean, default: false
    end
  end
end
