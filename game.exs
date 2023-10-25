defmodule Game do
  @default_options [
    # Number of cells per row and per column.
    board_dimensions: {3, 2},
    # Value of the singular piece present at the beginning of the game.
    starting_number: 2,
    # Value of the piece randomly inserted into the board at the beginning of
    # each turn.
    turn_start_number: 1,
    # Value of the piece which, when present on the board, results in a win.
    winning_number: 4
  ]
  @cell_size 5

  def init(opts \\ []) do
    opts = Keyword.validate!(opts, @default_options)

    game = %{
      board: starting_board(opts[:board_dimensions], opts[:starting_number]),
      score: 0,
      turns: 0,
      state: :running,
      turn_start_number: opts[:turn_start_number],
      winning_number: opts[:winning_number],
      # Size of each cell, to accommodate the largest (i.e. winning) number.
      cell_render_size: (opts[:winning_number] |> Integer.to_string() |> String.length()) + 2
    }

    render_game(game)
    game
  end

  def tick(%{state: :running} = game) do
    # Get input.
    move = get_move()
    # Update state.
    game = update(game, move)
    # Render.
    render_game(game)
    game
  end

  def run(%{state: :running} = game) do
    game
    |> tick()
    |> run()
  end

  def run(%{state: :won}) do
    IO.puts("You won!")
    :ok
  end

  def run(%{state: :exhausted}) do
    IO.puts("You lost!")
    :ok
  end

  defp starting_board({num_rows, num_cols}, starting_number) do
    empty_cells =
      for row <- 1..num_rows, col <- 1..num_cols, into: %{}, do: {{row, col}, nil}

    board = %{cells: empty_cells, dimensions: {num_rows, num_cols}}

    add_value(board, starting_number)
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

  defp exhausted?(%{board: %{cells: cells}} = _game) do
    # A game board is exhausted if, at the beginning of a turn, there is no
    # empty cells left on the board.
    cells
    |> Map.values()
    |> Enum.all?()
  end

  defp won?(%{board: %{cells: cells}, winning_number: winning_number} = _game) do
    # A game is won if, at the end of a turn, a cell contains the winning
    # number.
    cells
    |> Map.values()
    |> Enum.any?(fn value -> value == winning_number end)
  end

  defp render_game(%{board: board, turns: turns, score: score} = _game) do
    rendered_board = render_board(board)

    IO.puts("""
    Turn ##{turns}. Score: #{score}.

    #{rendered_board}
    """)
  end

  defp render_board(%{cells: cells, dimensions: {num_rows, num_cols}}) do
    Enum.map(1..num_rows, fn row ->
      Enum.map(1..num_cols, fn col ->
        render_cell(cells, {row, col})
      end)
      |> Enum.join("")
    end)
    |> Enum.join("\n")
  end

  defp render_cell(cells, coordinate) do
    cells
    |> render_value(coordinate)
    |> String.pad_leading(1)
    |> String.pad_trailing(@cell_size - 1)
  end

  defp render_value(cells, coordinate) do
    case cells[coordinate] do
      nil -> "-"
      value -> Integer.to_string(value)
    end
  end

  defp update(
         %{board: board, turns: turns, turn_start_number: turn_start_number, state: :running} =
           game,
         move
       ) do
    # TODO Increase score (by the sum of newly merged pieces).
    board = merge_values(board, move)
    board = move_values(board, move)
    # TODO only increment turns and check for wins/exhaustion if the move
    # actually modified the board.
    game = %{game | board: board, turns: turns + 1}

    if won?(game) do
      %{game | state: :won}
    else
      if exhausted?(game) do
        %{game | state: :exhausted}
      else
        %{game | board: add_value(board, turn_start_number)}
      end
    end
  end

  defp merge_values(%{cells: cells} = board, move) do
    updates =
      rows_for_move(board, move)
      |> Enum.map(fn row ->
        Enum.map(row, fn coord -> {coord, cells[coord]} end)
      end)
      |> Enum.flat_map(fn row ->
        new_row = Enum.into(row, %{})

        {new_row, _} =
          Enum.reduce(row, {new_row, nil}, fn {coord, current_value},
                                              {new_row, last_non_empty_coord} ->
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

    update_board(board, updates)
  end

  defp move_values(%{cells: cells} = board, move) do
    # Conceptually, for each 'row' of values being moved:
    # 1. Create a new row with all non-empty cells.
    # 2. Pad the row up to the board size with empty cells.
    updates =
      rows_for_move(board, move)
      |> Enum.flat_map(fn row ->
        # Non-empty cells in the same order they appear in the row.
        values =
          row
          |> Enum.map(&Map.fetch!(cells, &1))
          |> Enum.filter(& &1)

        # Empty cells needed to pad out the new row.
        padding = List.duplicate(nil, Enum.count(row) - Enum.count(values))

        # Zip the original coordinates with the new values.
        Enum.zip(row, values ++ padding)
      end)
      |> Enum.into(%{})

    update_board(board, updates)
  end

  defp update_board(%{cells: cells} = board, updates) do
    %{board | cells: Map.merge(cells, updates)}
  end

  defp rows_for_move(%{dimensions: {num_rows, num_cols}} = _board, :left) do
    for row <- 1..num_rows do
      for col <- 1..num_cols, do: {row, col}
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

  defp add_value(%{cells: cells} = board, value) do
    # Add the value to a randomly chosen empty coordinate.
    random_coord =
      cells
      |> Map.keys()
      |> Enum.filter(fn coord -> is_nil(cells[coord]) end)
      |> Enum.random()

    %{board | cells: Map.put(cells, random_coord, value)}
  end
end

game = Game.init()
Game.run(game)
