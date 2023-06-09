defmodule Cocktailparty.Catalog.Source do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sources" do
    field :channel, :string
    field :description, :string
    field :name, :string
    field :type, :string

    many_to_many :users, Cocktailparty.Accounts.User,
      join_through: "sources_subscriptions",
      on_replace: :delete,
      on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:name, :description, :type, :channel])
    |> validate_required([:name, :description, :type, :channel])
    |> unique_constraint(:name)
  end
end
