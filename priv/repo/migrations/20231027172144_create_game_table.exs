defmodule TwentyFortyEight.Repo.Migrations.CreateGameTable do
  use Ecto.Migration

  def change do
    create table(:game) do
      add :num_rows, :integer, default: 6, null: false
      add :num_cols, :integer, default: 6, null: false
      add :starting_number, :integer, default: 2, null: false
      add :turn_start_number, :integer, default: 1, null: false
      add :winning_number, :integer, default: 2048, null: false
      add :score, :integer, default: 0, null: false
      add :turns, :integer, default: 0, null: false
      add :state, :string, default: "new", null: false
      add :slug, :string, null: false
      add :board, :json

      timestamps()
    end

    create constraint(:game, "started_game_must_have_board",
             check: "state = 'new' OR board IS NOT NULL",
             comment: "Board must be non-null out of the new state."
           )

    create unique_index(:game, [:slug])
  end
end
