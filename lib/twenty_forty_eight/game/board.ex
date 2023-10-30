defmodule TwentyFortyEight.Game.Board do
  @moduledoc """
  Game board value store and business logic handler.
  """
  @enforce_keys [:cells, :num_rows, :num_cols]
  defstruct [:cells, :num_rows, :num_cols]

  @obstacle :obstacle
  @valid_moves [:up, :down, :left, :right]

  @type obstacle() :: :obstacle
  @type cell_value() :: pos_integer() | obstacle() | nil
  @type t() :: %__MODULE__{
          cells: %{{non_neg_integer(), non_neg_integer()} => cell_value()},
          num_rows: pos_integer(),
          num_cols: pos_integer()
        }

  @doc """
  Return a board with a single starting number and zero or more obstacles.
  """
  def init(num_rows, num_cols, starting_number, num_obstacles) do
    empty_cells =
      for row <- 1..num_rows, col <- 1..num_cols, into: %{}, do: {{row, col}, nil}

    %__MODULE__{cells: empty_cells, num_rows: num_rows, num_cols: num_cols}
    |> add_value(starting_number)
    |> add_obstacles(num_obstacles)
  end

  @doc """
  Return `board` with `value` inserted into a randomly chosen empty cell.
  """
  def add_value(%__MODULE__{cells: cells} = board, value) do
    random_coord =
      board
      |> cell_coordinates()
      |> Enum.filter(fn coord -> is_nil(cells[coord]) end)
      |> Enum.random()

    %__MODULE__{board | cells: Map.put(cells, random_coord, value)}
  end

  @doc """
  Return `board` with its values shifted and merged according to `move`. 
  """
  def apply_move(%__MODULE__{} = board, move) when move in @valid_moves do
    board
    |> merge_values(move)
    |> move_values(move)
  end

  @doc """
  Return true if two boards have identical cell coordinates and values.
  """
  def equal?(%__MODULE__{cells: a}, %__MODULE__{cells: b}) do
    Map.equal?(a, b)
  end

  @doc """
  Return true if no valid move can alter any cell values.
  """
  def unsolvable?(board) do
    @valid_moves
    |> Enum.map(&apply_move(board, &1))
    |> Enum.all?(&equal?(board, &1))
  end

  @doc """
  Return true if the board contains at least one instance of the value.
  """
  def has_value?(%__MODULE__{} = board, value) when is_integer(value) do
    board
    |> cell_values()
    |> Enum.any?(fn cell_value -> cell_value == value end)
  end

  defp add_obstacles(board, 0), do: board

  defp add_obstacles(board, num_remaining) when is_integer(num_remaining) do
    board
    |> add_value(@obstacle)
    |> add_obstacles(num_remaining - 1)
  end

  defp cells(%__MODULE__{cells: cells}), do: cells

  defp cell_coordinates(board) do
    board
    |> cells()
    |> Map.keys()
  end

  defp cell_values(board) do
    board
    |> cells()
    |> Map.values()
  end

  defp merge_values(board, move) do
    # For each row, we run a two-pointer algorithm where:
    #
    # * Pointer #1 iterates through the row.
    # * Pointer #2 points to the latest non-empty, non-modified cell behind
    #   pointer #1.
    #
    # As #1 iterates, if its current cell is not empty and:
    #
    # * Has the same value as the cell of #2: the cell of #1 will be merged into
    #   that of #2 (the #2 cell value will be doubled and the #1 cell will be
    #   emptied) and the #2 pointer will be nullified. Or;
    # * Does not have the same value as the cell of #2: the #2 pointer is
    #   updated to point to #1 before #1 continues its iteration.
    updates =
      rows_for_move(board, move)
      |> Enum.map(fn row ->
        Enum.map(row, fn coord -> {coord, board.cells[coord]} end)
      end)
      |> Enum.flat_map(&merge_row_values(&1))
      |> Enum.into(%{})

    update_board(board, updates)
  end

  defp merge_row_values(row) do
    # row is a list of {{row, col}, value} elements.
    new_row = Enum.into(row, %{})

    {new_row, _} =
      Enum.reduce(row, {new_row, nil}, fn {coord, current_value},
                                          {new_row, last_non_empty_coord} ->
        case current_value do
          nil ->
            {new_row, last_non_empty_coord}

          :obstacle ->
            {new_row, nil}

          _ ->
            if current_value == new_row[last_non_empty_coord] do
              {%{new_row | last_non_empty_coord => 2 * current_value, coord => nil}, nil}
            else
              {new_row, coord}
            end
        end
      end)

    Map.to_list(new_row)
  end

  defp move_values(board, move) do
    # Conceptually, for each 'row' of values being moved:
    # 1. Create a new row with all non-empty cells.
    # 2. Pad the row up to the board size with empty cells.
    updates =
      rows_for_move(board, move)
      |> Enum.flat_map(fn row ->
        # Non-empty cells in the same order they appear in the row.
        values =
          row
          |> Enum.map(&Map.fetch!(board.cells, &1))
          |> Enum.chunk_by(&(&1 == @obstacle))
          |> Enum.flat_map(fn chunked_row ->
            values = chunked_row |> Enum.filter(& &1)

            # Empty cells needed to pad out the new row.
            padding = List.duplicate(nil, Enum.count(chunked_row) - Enum.count(values))

            values ++ padding
          end)

        # Zip the original coordinates with the new values.
        Enum.zip(row, values)
      end)
      |> Enum.into(%{})

    update_board(board, updates)
  end

  defp update_board(board, updates) do
    %__MODULE__{board | cells: Map.merge(board.cells, updates)}
  end

  defp rows_for_move(board, :left) do
    for row <- 1..board.num_rows do
      for col <- 1..board.num_cols, do: {row, col}
    end
  end

  defp rows_for_move(board, :right) do
    board
    |> rows_for_move(:left)
    |> Enum.map(&Enum.reverse/1)
  end

  defp rows_for_move(board, :up) do
    board
    |> rows_for_move(:left)
    |> Enum.zip()
    |> Enum.map(&Tuple.to_list/1)
  end

  defp rows_for_move(board, :down) do
    board
    |> rows_for_move(:up)
    |> Enum.map(&Enum.reverse/1)
  end
end
