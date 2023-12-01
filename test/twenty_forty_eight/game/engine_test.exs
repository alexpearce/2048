defmodule TwentyFortyEight.Game.EngineTest do
  use ExUnit.Case, async: true

  alias TwentyFortyEight.Game.{Board, Engine}
  alias TwentyFortyEight.Test.Helpers, as: TestHelpers

  @default_init_options [winning_number: 2048, turn_start_number: 1]

  describe "init/2" do
    test "initialises the state to a new game" do
      board = Board.init(4, 4, 2, 1)
      winning_number = 512
      turn_start_number = 4
      opts = [winning_number: winning_number, turn_start_number: turn_start_number]
      state = Engine.init(board, opts)

      assert %{
               board: state_board,
               score: 0,
               state: :running,
               turn_start_number: ^turn_start_number,
               turns: 0,
               winning_number: ^winning_number
             } = state

      assert Board.equal?(board, state_board)
    end
  end

  describe "restore/1" do
    test "returns state restored from a map" do
      to_restore = %{
        board: Board.init(4, 3, 16, 3),
        score: 53,
        state: :running,
        turn_start_number: 2,
        turns: 12,
        winning_number: 1024
      }

      assert Map.equal?(to_restore, Engine.restore(to_restore))
    end
  end

  describe "tick/2" do
    test "applies the move to the board and adds a new number" do
      board =
        TestHelpers.ascii_to_board("""
        4 4 -
        """)

      turn_start_number = 1
      state = Engine.init(board, winning_number: 2048, turn_start_number: turn_start_number)

      %{board: updated_board} = Engine.tick(state, :right)

      # Expect move + merge, and turn start number to be added.
      # We have two possible boards because the turn start number is added randomly.
      expected_board_a =
        TestHelpers.ascii_to_board("""
        - #{turn_start_number} 8
        """)

      expected_board_b =
        TestHelpers.ascii_to_board("""
        #{turn_start_number} - 8
        """)

      assert Board.equal?(updated_board, expected_board_a) or
               Board.equal?(updated_board, expected_board_b)
    end

    test "increments the turn number" do
      board =
        TestHelpers.ascii_to_board("""
        4 4 -
        """)

      %{turns: turns} = state = Engine.init(board, @default_init_options)

      %{turns: updated_turns} = Engine.tick(state, :left)

      assert updated_turns == turns + 1
    end

    test "updates the score based on merges" do
      board =
        TestHelpers.ascii_to_board("""
        4 1 16
        4 - 16
        """)

      %{score: score} = state = Engine.init(board, @default_init_options)

      %{score: updated_score} = Engine.tick(state, :down)

      # Score has been updated (by +40 as we merged 4+4 and 16+16).
      assert updated_score == score + 40
    end

    test "marks the game as lost if the resulting board is unsolvable" do
      board =
        TestHelpers.ascii_to_board("""
        2 4
        4 4
        """)

      state = Engine.init(board, @default_init_options)

      assert %{state: :lost} = Engine.tick(state, :up)
    end

    test "changes state to won if winning number is reached" do
      board =
        TestHelpers.ascii_to_board("""
        4 4
        """)

      state = Engine.init(board, winning_number: 8, turn_start_number: 1)

      assert %{state: :won} = Engine.tick(state, :right)
    end

    test "does not modify any state if board does not change" do
      board =
        TestHelpers.ascii_to_board("""
        2 4
        4 -
        """)

      state = Engine.init(board, @default_init_options)

      updated_state = Engine.tick(state, :left)

      # The board has not changed.
      assert Board.equal?(updated_state.board, board)
      # And indeed the entire state remains unchanged.
      assert Map.equal?(updated_state, state)
    end
  end
end
