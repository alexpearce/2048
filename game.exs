defmodule Game do
  # Size of each board side.
  @board_size 4
  # Value of the singular piece present at the beginning of the game.
  @starting_number 2
  # Value of the piece randomly inserted into the board at the beginning of
  # each turn.
  @turn_number 1
  # Value of the piece which, when present on the board, results in a win.
  @winning_number 2048
  # Size of each cell, to accommodate the largest (i.e. winning) number.
  @cell_size (@winning_number |> Integer.to_string() |> String.length()) + 2

  def init do
    board = starting_board()
    %{board: board, score: 0, turns: 0, terminated: false}
  end

  def run(%{terminated: false} = state) do
    state = if won?(state) do
      %{state | terminated: true}
    else
      IO.puts(view(state))
      move = get_move()
      state = update(state, move)
      %{state | terminated: exhausted?(state)}
    end

    run(state)
  end

  def run (%{terminated: true} = state) do
    IO.puts(view(state))
    IO.puts("End!")
    :ok
  end

  defp starting_board do
    empty_board = for x <- 1..@board_size, y <- 1..@board_size, into: %{}, do: {{x, y}, nil}
    add_value(empty_board, @starting_number)
  end

  defp get_move() do
    "Next move (hjkl): "
    |> IO.gets()
    |> String.trim()
    |> input_to_move()
  end

  defp input_to_move("h"), do: :left
  defp input_to_move("j"), do: :down
  defp input_to_move("k"), do: :up
  defp input_to_move("l"), do: :right

  defp exhausted?(%{board: board} = _state) do
    # A game board is exhausted if, at the beginning of a turn, there is no
    # space left on the board.
    board
    |> Map.values()
    |> Enum.all?()
  end

  defp won?(%{board: board} = _state) do
    # A game is won if, at the beginning of a turn, the game contains the
    # winning number.
    board
    |> Map.values()
    |> Enum.any?(fn value -> value == @winning_number end)
  end

  defp view(%{board: board, turns: turns, score: score} = _state) do
    rendered_board = render_board(board)
    """
    Turn ##{turns}. Score: #{score}.

    #{rendered_board}
    """
  end

  defp render_board(board) do
    Enum.map(1..@board_size, fn row ->
      Enum.map(1..@board_size, fn col ->
        render_cell(board, {row, col})
      end)
      |> Enum.join("")
    end)
    |> Enum.join("\n")
  end

  defp render_cell(board, coordinate) do
    board
    |> render_value(coordinate)
    |> String.pad_leading(1)
    |> String.pad_trailing(@cell_size - 1)
  end

  defp render_value(board, coordinate) do
    case board[coordinate] do
      nil -> "-"
      value -> Integer.to_string(value)
    end
  end

  defp update(%{board: board, turns: turns} = state, move) do
    # 1. Merge pieces.
    board = merge_values(board, move)
    # 2. Move pieces.
    board = move_values(board, move)
    # 3. Insert new piece if pieces were merged or moved.
    # TODO gross that we check exhaustion here as well as the main game loop;
    # would ideally insert the new element at the start of the main loop.
    board = if exhausted?(state), do: board, else: add_value(board, @turn_number)
    # 4. Increment turn number if pieces were merged or moved.
    # 5. Increase score (by the sum of newly merged pieces).
    %{state | board: board, turns: turns + 1}
  end

  defp merge_values(board, move) do
    updates =
    board
    |> rows_for_move(move)
    |> Enum.map(fn row ->
      Enum.map(row, fn coord -> {coord, board[coord]} end)
    end)
    |> Enum.flat_map(fn row ->
      new_row = Enum.into(row, %{})
      {new_row, _} = Enum.reduce(row, {new_row, nil}, fn {coord, current_value}, {new_row, last_non_empty_coord} ->
        if is_nil(current_value) do
          {new_row, last_non_empty_coord}
        else
          if current_value == new_row[last_non_empty_coord] do
            {%{new_row | last_non_empty_coord => 2 * current_value, coord => nil}, nil}
          else
            {new_row, coord}
          end
        end
      end)
      Map.to_list(new_row)
    end)
    |> Enum.into(%{})

    Map.merge(board, updates)
  end

  defp move_values(board, move) do
    # Conceptually, for each 'row' of values being moved:
    # 1. Create a new row with all non-empty cells.
    # 2. Pad the row up to the board size with empty cells.
    updates = rows_for_move(board, move)
    |> Enum.flat_map(fn row ->
      # Non-empty cells in the same order they appear in the row.
      values =
      row
      |> Enum.map(&Map.fetch!(board, &1))
      |> Enum.filter(& &1)

      # Empty cells needed to pad out the new row.
      padding = List.duplicate(nil, Enum.count(row) - Enum.count(values))

      # Zip the original coordinates with the new values.
      Enum.zip(row, values ++ padding)
    end)
    |> Enum.into(%{})

    Map.merge(board, updates)
  end

  defp rows_for_move(board, :left) do
    for row <- 1..@board_size do
      for col <- 1..@board_size, do: {row, col}
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

  defp add_value(board, value) do
    # Add the value to a randomly chosen empty coordinate.
    random_coord = 
    board
    |> Map.keys()
    |> Enum.filter(fn coord -> is_nil(board[coord]) end)
    |> Enum.random()

    %{board | random_coord => value}
  end
end

state = Game.init()
Game.run(state)