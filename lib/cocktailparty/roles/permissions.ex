defmodule Cocktailparty.Roles.Permissions do
  @moduledoc """
  The permission module is an embedded_schema that aims to being embedded into a role.
  Its fields are stored as JSONB in postgres. it is done that way to avoid having to run migration
  when adding new permissions.

  As permissions grant access to several features, this module contains  the definition of callbacks
  for permissions: for instance when the permission :create_sinks is removed from a role,
  all sinks created by users having this role shall be immediately deleted, and the corresponding
  processes (and associated connections) killed.

  To add a permission, add a field to the embedded_schema:
    field :test, :boolean, default: false

  To create a callback, add a function with the same name. The Roles module will call it with the
  role, and the direction (promotion or demotion) ie.:

  def test(role, direction) do
    case direction do
      "promotion" ->
        # Promotion code for test
      "demotion" ->
        # Demotion code for test
        _->
          false
    end
  end
  """
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  @primary_key false
  embedded_schema do
    field :access_all_sources, :boolean, default: false
    field :list_all_sources, :boolean, default: false
    field :create_sinks, :boolean, default: false
    field :test, :boolean, default: false
    # more permission to come
  end

  def list_permissions() do
    __schema__(:fields)
  end

  def get_permissions_labels() do
    Enum.reduce(__schema__(:fields), %{}, fn x, acc ->
      Map.put(acc, x, get_permission_label(x))
    end)
  end

  def get_permission_label(permission) do
    permission
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.with_index()
    |> Enum.map_join(" ", fn
      {word, 0} -> String.capitalize(word)
      {word, _} -> word
    end)
  end

  def changeset(permissions, attrs) do
    permissions
    |> cast(attrs, [:access_all_sources, :list_all_sources, :create_sinks, :test])
    |> validate_required([:access_all_sources, :list_all_sources, :create_sinks, :test])
  end

  @doc """
  Callback for :access_all_sources:
    - demotion:
      - kick all users from channel joined thanks to this permission
  """
  def access_all_sources(role = %Cocktailparty.Roles.Role{}, direction) do
    if direction == "demotion" do
      # get all users affected by the change
      affected_users = Cocktailparty.Roles.list_users_with_role(role.id)

      affected_users_id =
        Enum.reduce(affected_users, [], fn x, acc ->
          acc ++ [x.id]
        end)

      # kick all users that were granted access to a source thanks to
      # the :access_all_sources permission
      Cocktailparty.Catalog.kick_non_subscribed(affected_users_id)
    end
  end

  @doc """
  Call back for :create_sinks
    - demotion:
      - we kill the socket linked to the sink that users created when they had the permission
      - delete said sinks from Repo
  """
  def create_sinks(role = %Cocktailparty.Roles.Role{}, direction) do
    if direction == "demotion" do
      # get all users affected by the change
      affected_users = Cocktailparty.Roles.list_users_with_role(role.id)

      affected_users_id =
        Enum.reduce(affected_users, [], fn x, acc ->
          acc ++ [x.id]
        end)

      # we kill the socket and delete the created sinks
      Cocktailparty.SinkCatalog.destroy_sinks_for_users(affected_users_id)
    end
  end
end
