defmodule Cocktailparty.Repo.Migrations.AddRoles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string
      # permissions will be an embedded struct in role
      # ecto will serialize this struct(map) as JSONB in postgreSQL
      add :permissions, :map
      timestamps()
    end

    alter table(:users) do
      add :role_id, references(:roles, on_delete: :nothing)
      remove :role
    end
  end
end
