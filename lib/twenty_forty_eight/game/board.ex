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
    empty_cells = for row <- 1..num_rows, col <- 1..num_cols, into: %{}, do: {{row, col}, nil}

    %__MODULE__{cells: empty_cells, num_rows: num_rows, num_cols: num_cols}
    |> add_value(starting_number)
    |> add_obstacles(num_obstacles)
  end

  @doc """
  Return `board` with `value` inserted into a randomly chosen empty cell.
  """
  def add_value(%__MODULE__{} = board, value) do
    %{cells: cells} = board

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
    cells =
      matrix_for_move(board, move)
      |> move_rows()
      |> merge_rows()
      |> move_rows()
      |> cells_from_matrix(move)

    %__MODULE__{board | cells: cells}
  end

  @doc """
  Return true if two boards have identical cell coordinates and values.
  """
  def equal?(%__MODULE__{} = a, %__MODULE__{} = b) do
    Map.equal?(a.cells, b.cells)
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

  defp cell_coordinates(board) do
    Map.keys(board.cells)
  end

  defp cell_values(board) do
    Map.values(board.cells)
  end

  defp move_rows(rows), do: Enum.map(rows, &move_row(&1, [], []))

  defp move_row([], acc, nils), do: Enum.reverse(nils ++ acc)
  defp move_row([nil | rest], acc, nils), do: move_row(rest, acc, [nil | nils])
  defp move_row([@obstacle | rest], acc, nils), do: move_row(rest, [@obstacle | nils ++ acc], [])
  defp move_row([cell | rest], acc, nils), do: move_row(rest, [cell | acc], nils)

  defp merge_rows(rows), do: Enum.map(rows, &merge_row(&1, []))

  defp merge_row([], acc), do: Enum.reverse(acc)

  # When we encounter two consecutive cells with the same integer value,
  # merge them into one and leave the other blank.
  defp merge_row([number, number | rest], acc) when is_integer(number),
    do: merge_row(rest, [number + number, nil | acc])

  defp merge_row([cell | rest], acc), do: merge_row(rest, [cell | acc])

  defp matrix_for_move(board, move) do
    rows = rows_for_move(board, move)

    for row <- rows do
      for coord <- row do
        Map.fetch!(board.cells, coord)
      end
    end
  end

  defp cells_from_matrix(matrix, :left) do
    for {row, row_idx} <- Enum.with_index(matrix, 1),
        {el, col_idx} <- Enum.with_index(row, 1),
        into: %{} do
      {{row_idx, col_idx}, el}
    end
  end

  defp cells_from_matrix(matrix, :right) do
    matrix
    |> Enum.map(&Enum.reverse/1)
    |> cells_from_matrix(:left)
  end

  defp cells_from_matrix(matrix, :up) do
    matrix
    |> Enum.zip()
    |> Enum.map(&Tuple.to_list/1)
    |> cells_from_matrix(:left)
  end

  defp cells_from_matrix(matrix, :down) do
    matrix
    |> Enum.map(&Enum.reverse/1)
    |> cells_from_matrix(:up)
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
