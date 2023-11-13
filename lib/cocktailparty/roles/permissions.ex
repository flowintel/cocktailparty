defmodule Cocktailparty.Roles.Permissions do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :list_all_sources, :boolean, default: false
    field :create_sink, :boolean, default: false
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
    |> cast(attrs, [:list_all_sources, :create_sink, :test])
    |> validate_required([:list_all_sources, :create_sink, :test])
  end
end
