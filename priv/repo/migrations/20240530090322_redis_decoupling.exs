defmodule Cocktailparty.Repo.Migrations.RedisDecoupling do
  use Ecto.Migration

  def change do
    rename table(:redis_instances), to: table(:connections)
    rename table(:sources), :redis_instance_id, to: :connection_id
    rename table(:sinks), :redis_instance_id, to: :connection_id

    alter table(:connections) do
      add :type, :string, null: false, default: "redis"
      add :config, :map, null: false, default: %{}
      remove :port
      remove :hostname
    end

    alter table(:sources) do
      add :config, :map, null: false, default: %{}
      remove :channel
      modify :connection_id, references(:connections, on_delete: :delete_all), null: false
    end

    alter table(:sinks) do
      add :config, :map, null: false, default: %{}
      remove :channel
      modify :connection_id, references(:connections, on_delete: :delete_all), null: false
    end

    create unique_index(:connections, [:name])
  end
end
