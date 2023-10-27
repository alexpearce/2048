defmodule TwentyFourtyEight.Game.Game do
  use Ecto.Schema
  import Ecto.Changeset

  alias TwentyFourtyEight.Repo

  @slug_length 8
  @slug_alphabet String.graphemes(
                   "_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
                 )

  schema "game" do
    field :num_rows, :integer, default: 6
    field :num_cols, :integer, default: 6
    field :starting_number, :integer, default: 2
    field :turn_start_number, :integer, default: 1
    field :winning_number, :integer, default: 2048
    field :slug, :string
    field :score, :integer
    field :turns, :integer
    field :state, Ecto.Enum, values: [:new, :running, :won, :exhausted]
    field :board, :map
    timestamps()
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:num_rows, :num_cols, :starting_number, :turn_start_number, :winning_number])
    |> validate_inclusion(:num_rows, 1..6)
    |> validate_inclusion(:num_cols, 1..6)
    |> validate_inclusion(:starting_number, [1, 2, 4])
    |> validate_inclusion(:turn_start_number, [1, 2, 4])
    |> validate_inclusion(:winning_number, [1024, 2048])
  end

  def insert(changeset) do
    changeset
    |> cast(%{slug: generate_slug()}, [:slug])
    |> unique_constraint(:slug)
    |> Repo.insert()
  end

  def get_by_slug(slug) do
    Repo.get_by(__MODULE__, slug: slug)
  end

  defp generate_slug() do
    1..@slug_length
    |> Enum.map_join("", fn _ -> Enum.random(@slug_alphabet) end)
  end
end
