defmodule TwentyFortyEight.Game.BoardTest do
  use ExUnit.Case

  alias TwentyFortyEight.Game.Board

  describe "init/4" do
    test "initialises a board" do
      for num_rows <- 2..6,
          num_cols <- 2..6,
          num_obstacles <- 0..2,
          starting_number <- [1, 2, 4] do
        num_empty = num_rows * num_cols - num_obstacles - 1

        board = Board.init(num_rows, num_cols, starting_number, num_obstacles)

        assert %Board{num_rows: ^num_rows, num_cols: ^num_cols, cells: _} = board
        assert {[^starting_number], ^num_obstacles, ^num_empty} = cell_contents(board)
      end
    end
  end

  describe "add_value/2" do
    test "adds a value to a random empty cell" do
      board = Board.init(4, 4, 2, 1)

      added = Board.add_value(board, 4)
      assert {[2, 4], _, _} = cell_contents(added)

      added = Board.add_value(board, 2)
      assert {[2, 2], _, _} = cell_contents(added)

      added = Board.add_value(board, 1)
      assert {[1, 2], _, _} = cell_contents(added)

      # Run a few times in case we randomly place two values at the same spot.
      assert Enum.any?(
               Enum.map(1..5, fn _idx ->
                 board_a = Board.add_value(board, 4)
                 board_b = Board.add_value(board, 4)
                 not Board.equal?(board_a, board_b)
               end)
             )
    end

    test "fails to add a value to a full board" do
      board = Board.init(2, 2, 1, 0)

      # Fill up the board.
      full = Enum.reduce(1..3, board, fn _idx, board -> Board.add_value(board, 1) end)
      assert {[1, 1, 1, 1], _, _} = cell_contents(full)

      # Try to insert a new value.
      assert_raise(Enum.EmptyError, fn ->
        Board.add_value(full, 1)
      end)
    end
  end

  describe "equal?/2" do
    test "two boards with equal dimensions and cell contents are equal" do
      board_a =
        ascii_to_board("""
        2 - -
        - * 2
        - - -
        """)

      board_b =
        ascii_to_board("""
        2 - -
        - * 2
        - - -
        """)

      # Boards should be equal to themselves.
      assert Board.equal?(board_a, board_a)
      assert Board.equal?(board_b, board_b)
      # The two board instances are also considered equal.
      assert Board.equal?(board_a, board_b)
    end

    test "two boards with equal dimensions but different cell contents are not equal" do
      board_a =
        ascii_to_board("""
        2 - -
        - * 2
        - - -
        """)

      board_b =
        ascii_to_board("""
        2 - -
        - 2 *
        - - -
        """)

      refute Board.equal?(board_a, board_b)
    end

    test "two boards of different dimensions are not identical" do
      board_a =
        ascii_to_board("""
        2 - -
        - * 2
        - - -
        """)

      board_b =
        ascii_to_board("""
        2 -
        * 2
        """)

      refute Board.equal?(board_a, board_b)
    end
  end

  describe "apply_move/2" do
    test "moves pieces up" do
      board =
        ascii_to_board("""
        2 - -
        - * 2
        - 4 -
        """)

      moved =
        ascii_to_board("""
        2 - 2
        - * -
        - 4 -
        """)

      assert Board.equal?(Board.apply_move(board, :up), moved)
    end

    test "moves pieces down" do
      board =
        ascii_to_board("""
        2 - -
        - * 2
        - 4 -
        """)

      moved =
        ascii_to_board("""
        - - -
        - * -
        2 4 2
        """)

      assert Board.equal?(Board.apply_move(board, :down), moved)
    end

    test "moves pieces left" do
      board =
        ascii_to_board("""
        2 - -
        - * 2
        - 4 -
        """)

      moved =
        ascii_to_board("""
        2 - -
        - * 2
        4 - -
        """)

      assert Board.equal?(Board.apply_move(board, :left), moved)
    end

    test "moves pieces right" do
      board =
        ascii_to_board("""
        2 - -
        - * 2
        - 4 -
        """)

      moved =
        ascii_to_board("""
        - - 2
        - * 2
        - - 4
        """)

      assert Board.equal?(Board.apply_move(board, :right), moved)
    end

    test "moves and merges pieces up" do
      board =
        ascii_to_board("""
        4 4 2
        4 * 2
        4 4 8
        """)

      moved =
        ascii_to_board("""
        8 4 4
        4 * 8
        - 4 -
        """)

      assert Board.equal?(Board.apply_move(board, :up), moved)
    end

    test "moves and merges pieces down" do
      board =
        ascii_to_board("""
        4 4 2
        4 * 2
        4 4 8
        """)

      moved =
        ascii_to_board("""
        - 4 -
        4 * 4
        8 4 8
        """)

      assert Board.equal?(Board.apply_move(board, :down), moved)
    end

    test "moves and merges pieces left" do
      board =
        ascii_to_board("""
        4 4 2
        4 * 2
        4 4 8
        """)

      moved =
        ascii_to_board("""
        8 2 -
        4 * 2
        8 8 -
        """)

      assert Board.equal?(Board.apply_move(board, :left), moved)
    end

    test "moves and merges pieces right" do
      board =
        ascii_to_board("""
        4 4 2
        4 * 2
        4 4 8
        """)

      moved =
        ascii_to_board("""
        - 8 2
        4 * 2
        - 8 8
        """)

      assert Board.equal?(Board.apply_move(board, :right), moved)
    end

    test "big move and merge" do
      board =
        ascii_to_board("""
        2  2  8  8   1024 1024 512
        64 64 *  128 *    128  128
        16 -  -  -   16   -    -
        4  2  4  4   4    4    2
        """)

      moved =
        ascii_to_board("""
        - -   -  4   16 2048 512
        - 128 *  128 *  -    256
        - -   -  -   -  -    32
        - -   4  2   8  8    2
        """)

      assert Board.equal?(Board.apply_move(board, :right), moved)
    end
  end

  describe "unsolvable?/1" do
    test "a full board with no possible merges is unsolvable" do
      board =
        ascii_to_board("""
        2 4
        4 2
        """)

      assert Board.unsolvable?(board)
    end

    test "a full board with possible merges is not unsolvable" do
      board =
        ascii_to_board("""
        2 4
        2 8
        """)

      refute Board.unsolvable?(board)

      board =
        ascii_to_board("""
        2 4
        2 *
        """)

      refute Board.unsolvable?(board)
    end

    test "a board with empty spaces not unsolvable" do
      board =
        ascii_to_board("""
        2 4
        4 -
        """)

      refute Board.unsolvable?(board)
    end
  end

  describe "has_value?/1" do
    test "returns true if the board contains the value" do
      board =
        ascii_to_board("""
        2 4
        4 *
        """)

      assert Board.has_value?(board, 2)
      assert Board.has_value?(board, 4)
    end

    test "returns false if the board does not contain the value" do
      board =
        ascii_to_board("""
        2 4
        4 *
        """)

      refute Board.has_value?(board, 1)
      refute Board.has_value?(board, 8)
    end
  end

  defp ascii_to_board(ascii) do
    rows =
      ascii
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(&String.split/1)

    num_rows = Enum.count(rows)
    assert num_rows > 0

    [num_cols | _] = row_sizes = Enum.map(rows, &Enum.count/1)
    assert Enum.all?(row_sizes, fn row_size -> row_size == num_cols end)

    cells =
      for {row, row_idx} <- Enum.with_index(rows),
          {character, col_idx} <- Enum.with_index(row),
          into: %{} do
        {{1 + row_idx, 1 + col_idx}, ascii_to_cell_value(character)}
      end

    %Board{num_rows: num_rows, num_cols: num_cols, cells: cells}
  end

  defp ascii_to_cell_value("-"), do: nil

  defp ascii_to_cell_value("*"), do: :obstacle

  defp ascii_to_cell_value(ascii), do: String.to_integer(ascii)

  defp cell_contents(board) do
    {numeric_cells(board), count_obstacles(board), count_empty(board)}
  end

  defp numeric_cells(%Board{cells: cells}) do
    Enum.filter(cells, fn {_, value} -> is_number(value) end)
    |> Enum.map(fn {_, value} -> value end)
    |> Enum.sort()
  end

  defp count_obstacles(%Board{cells: cells}) do
    Enum.count(cells, fn {_, value} -> value == :obstacle end)
  end

  defp count_empty(%Board{cells: cells}) do
    Enum.count(cells, fn {_, value} -> is_nil(value) end)
  end
end
