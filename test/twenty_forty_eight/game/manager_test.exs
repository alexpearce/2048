defmodule TwentyFortyEight.Game.ManagerTest do
  use TwentyFortyEight.DataCase, async: true

  alias TwentyFortyEight.Game.Manager
  alias TwentyFortyEight.Repo

  describe "get/1" do
    test "returns a struct when a game exists" do
      name = "ABC123"
      :ok = insert_game(name)
      assert {:ok, %Manager{name: ^name}} = Manager.get(name)
    end

    test "returns the correct data when multiple games exist" do
    end

    test "returns an error tuple if a game does not exist" do
      assert {:error, :not_found} = Manager.get("ABC123")
    end
  end

  describe "tick/2" do
    test "propagates ticks to the engine" do
      name = "ABC123"
      %Manager{engine: %{turns: 0}} = manager = create_manager(name)
      %Manager{engine: %{turns: turns}} = cycle_moves(manager)
      assert turns > 0
    end

    test "does not persist changes to the DB" do
      name = "ABC123"

      name
      |> create_manager()
      |> cycle_moves()

      # The DB still has the game marked 'new' with no turns recorded.
      assert %{rows: [[^name, "new", 0, nil]]} =
               Repo.query!("SELECT slug, state, turns, board FROM game")
    end
  end

  describe "save/1" do
    test "stores the game and engine state in the DB" do
      name = "ABC123"

      manager =
        name
        |> create_manager()
        |> cycle_moves()

      assert :ok = Manager.save(manager)

      assert %{rows: [[^name, "running", turns, board]]} =
               Repo.query!("SELECT slug, state, turns, board FROM game")

      assert turns > 0
      # The board contents have been serialised.
      assert %{"cells" => cells} = board
      assert Enum.count(cells) == 4 * 4
    end

    test "stores the state in a way that can be restored exactly" do
      name = "ABC123"

      manager =
        name
        |> create_manager()
        |> cycle_moves()

      :ok = Manager.save(manager)

      {:ok, restored_manager} = Manager.get(name)
      assert restored_manager == manager
    end
  end

  defp create_manager(name) do
    :ok = insert_game(name)
    {:ok, manager} = Manager.get(name)
    manager
  end

  defp insert_game(name) do
    now = DateTime.utc_now()

    %{num_rows: 1} =
      Repo.query!(
        """
        INSERT INTO game (num_rows, num_cols, starting_number, num_obstacles, turn_start_number, winning_number, slug, score, turns, state, board, inserted_at, updated_at)
        VALUES (4, 4, 2, 1, 1, 2048, $1, 0, 0, 'new', null, $2, $2)
        """,
        [name, now]
      )

    :ok
  end

  defp cycle_moves(manager) do
    # Tests that check for changes cannot perform only a single move because
    # that may not change the board. Cycle through a few moves to ensure the board
    # changes.
    manager
    |> Manager.tick(:up)
    |> Manager.tick(:down)
    |> Manager.tick(:left)
    |> Manager.tick(:right)
  end
end
