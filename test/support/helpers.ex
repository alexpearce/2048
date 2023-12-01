defmodule TwentyFortyEight.Test.Helpers do
  @moduledoc false

  alias TwentyFortyEight.Game.Board

  def ascii_to_board(ascii) do
    rows =
      ascii
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(&String.split/1)

    num_rows = Enum.count(rows)
    if num_rows == 0, do: raise("Need non-zero number of rows.")

    [num_cols | _] = row_sizes = Enum.map(rows, &Enum.count/1)
    consistent_rows? = Enum.all?(row_sizes, fn row_size -> row_size == num_cols end)
    if not consistent_rows?, do: raise("All rows must have equal length.")

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
end
