defmodule TwentyFortyEight.Game.GameTest do
  use TwentyFortyEight.DataCase, async: true

  alias TwentyFortyEight.Repo
  alias TwentyFortyEight.Game.Game

  describe "create_changeset/1" do
    test "returns a valid changeset" do
      changeset = Game.create_changeset(%{})
      assert changeset.valid?
    end

    test "generates a random slug" do
      changeset_a = Game.create_changeset(%{})
      changeset_b = Game.create_changeset(%{})
      assert changeset_a.changes.slug != changeset_b.changes.slug
    end

    test "validates num_rows to be between 1 and 6" do
      for invalid <- [-1, 0, 7, 10] do
        changeset = Game.create_changeset(%{num_rows: invalid})
        refute changeset.valid?
      end

      for valid <- 1..6 do
        changeset = Game.create_changeset(%{num_rows: valid})
        assert changeset.valid?
      end
    end

    test "validates num_cols to be between 1 and 6" do
      for invalid <- [-1, 0, 7, 10] do
        changeset = Game.create_changeset(%{num_cols: invalid})
        refute changeset.valid?
      end

      for valid <- 1..6 do
        changeset = Game.create_changeset(%{num_cols: valid})
        assert changeset.valid?
      end
    end

    test "validates num_obstacles to be between 0 and 6" do
      for invalid <- [-1, 7, 10] do
        changeset = Game.create_changeset(%{num_obstacles: invalid})
        refute changeset.valid?
      end

      for valid <- 0..6 do
        changeset = Game.create_changeset(%{num_obstacles: valid})
        assert changeset.valid?
      end
    end

    test "validates starting_number to be 1, 2, or 4" do
      for invalid <- [-1, 0, 3, 8] do
        changeset = Game.create_changeset(%{starting_number: invalid})
        refute changeset.valid?
      end

      for valid <- [1, 2, 4] do
        changeset = Game.create_changeset(%{starting_number: valid})
        assert changeset.valid?
      end
    end

    test "validates turn_start_number to be 1, 2, or 4" do
      for invalid <- [-1, 0, 3, 8] do
        changeset = Game.create_changeset(%{turn_start_number: invalid})
        refute changeset.valid?
      end

      for valid <- [1, 2, 4] do
        changeset = Game.create_changeset(%{turn_start_number: valid})
        assert changeset.valid?
      end
    end

    test "validates winning_number to be 1024 or 2048" do
      for invalid <- [-1, 0, 1, 2, 3, 8, 512] do
        changeset = Game.create_changeset(%{winning_number: invalid})
        refute changeset.valid?
      end

      for valid <- [1024, 2048] do
        changeset = Game.create_changeset(%{winning_number: valid})
        assert changeset.valid?
      end
    end
  end

  describe "insert/1" do
    test "successfully inserts a valid changeset" do
      {:ok, game} = %{} |> Game.create_changeset() |> Game.insert()

      assert Repo.get(Game, game.id)
    end

    test "does not insert an invalid changeset" do
      game = %{num_rows: 0} |> Game.create_changeset()

      assert {:error, _error} = Game.insert(game)

      refute Repo.exists?(Game)
    end
  end

  describe "get_by_slug/1" do
    test "returns an existing game" do
      %Game{id: id, slug: slug} = create_game()

      assert %Game{id: ^id} = Game.get_by_slug(slug)
    end

    test "returns nil for a non-existent game" do
      refute Game.get_by_slug("abc")
    end
  end

  describe "update_changeset/2" do
    test "returns a valid changeset" do
      game = create_game(%{state: "new"})

      changes = %{
        board: %{},
        score: 0,
        turns: 0,
        state: :running
      }

      changeset = Game.update_changeset(game, changes)

      assert changeset.valid?
    end

    test "allows new or running state to transition to running" do
      for {state, board} <- [{"new", nil}, {"running", %{}}] do
        game = create_game(%{state: state, board: board})

        changes = %{
          board: %{},
          score: 0,
          turns: 0,
          state: :running
        }

        changeset = Game.update_changeset(game, changes)

        assert changeset.valid?
      end
    end

    test "does not allow state to update to 'new'" do
      for state <- ["new", "running", "won", "lost"] do
        board = if state == "new", do: nil, else: %{}
        game = create_game(%{state: state, board: board})

        changes = %{
          board: %{},
          score: 0,
          turns: 0,
          state: :new
        }

        changeset = Game.update_changeset(game, changes)

        refute changeset.valid?
      end
    end

    test "does not allow state to transition from terminal to non-terminal" do
      for terminal <- ["won", "lost"], active <- ["new", "running"] do
        game = create_game(%{state: terminal, board: %{}})

        changes = %{
          board: %{},
          score: 0,
          turns: 0,
          state: active
        }

        changeset = Game.update_changeset(game, changes)

        refute changeset.valid?
      end
    end
  end

  describe "update/2" do
    test "updates with valid changes" do
      game = create_game(%{state: "new", board: nil})

      changes = %{
        board: %{},
        score: 0,
        turns: 0,
        state: "running"
      }

      assert {:ok, %Game{state: :running}} = Game.update(game, changes)
      assert %Game{state: :running} = Repo.get(Game, game.id)
    end

    test "does not update with invalid changes" do
      game = create_game(%{state: "won", board: %{}})

      changes = %{
        board: %{},
        score: 0,
        turns: 0,
        state: "lost"
      }

      assert {:error, _error} = Game.update(game, changes)
      assert %Game{state: :won} = Repo.get(Game, game.id)
    end
  end

  defp create_game(attrs \\ %{}) do
    now = DateTime.utc_now()

    default_attrs = [
      num_rows: 4,
      num_cols: 4,
      starting_number: 2,
      num_obstacles: 1,
      turn_start_number: 2,
      winning_number: 2048,
      slug: "#{System.unique_integer()}",
      score: 0,
      turns: 0,
      state: "new",
      board: nil,
      inserted_at: now,
      updated_at: now
    ]

    attrs = Map.merge(Map.new(default_attrs), attrs)
    params = Enum.map(Keyword.keys(default_attrs), &Map.fetch!(attrs, &1))

    Repo.query!(
      """
      INSERT INTO game (num_rows, num_cols, starting_number, num_obstacles, turn_start_number, winning_number, slug, score, turns, state, board, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::json, $12, $13)
      """,
      params
    )

    Repo.get_by(Game, slug: attrs.slug)
  end
end
