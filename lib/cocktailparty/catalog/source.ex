defmodule Cocktailparty.Catalog.Source do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sources" do
    field :name, :string
    field :type, :string
    field :config, :map
    field :public, :boolean
    field :description, :string

    many_to_many :users, Cocktailparty.Accounts.User,
      join_through: "sources_subscriptions",
      on_replace: :delete,
      on_delete: :delete_all

    belongs_to :connection, Cocktailparty.Input.Connection

    timestamps()
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:name, :type, :description, :config, :connection_id, :public])
    |> validate_required([:name, :type, :config])
    |> unique_constraint(:name)
  end
end
