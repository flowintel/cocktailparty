defmodule Cocktailparty.Catalog.Source do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sources" do
    field :channel, :string
    field :description, :string
    field :driver, :string
    field :name, :string
    field :type, :string
    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:name, :description, :driver, :type, :url, :channel])
    |> validate_required([:name, :description, :driver, :type, :url, :channel])
  end
end
