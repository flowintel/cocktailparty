defmodule Cocktailparty.Repo.Migrations.MoveUsersToNewRoles do
  use Ecto.Migration

  def up do
    default_role_id = 1
    # Insert the default role
    execute "INSERT INTO roles (id, name, permissions, inserted_at, updated_at) VALUES ('#{default_role_id}', 'user', '{}', NOW(), NOW())"
    # Update existing users to have the default role
    execute "UPDATE users SET role_id = '#{default_role_id}' WHERE role_id IS NULL"
  end

  def down do
    # Remove the default role association from users
    execute "UPDATE users SET role_id = NULL"
    # Optionally, delete the default role if rolling back
    execute "DELETE FROM roles WHERE id= 1"
  end
end
