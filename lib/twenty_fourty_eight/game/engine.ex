defmodule TwentyFourtyEight.Game.Engine do
  # TODO
  # 1. rename Fourty -> Forty
  # 2. mark a game as lost if, at the start of a turn, the board is exhausted and no move would change that
  # 3. factor out board creation into a separate module. the engine's state can then be reduced (doesn't need stuff only required to create the board.)
  # 4. fix obstacle creation and make it configurable.
  @default_new_options [
    # Number of cells per row and per column.
    board_dimensions: {6, 6},
    # Value of the singular piece present at the beginning of the game.
    starting_number: 2,
    # Value of the piece randomly inserted into the board at the beginning of
    # each turn.
    turn_start_number: 1,
    # Value of the piece which, when present on the board, results in a win.
    winning_number: 2048
  ]
  @obstacles 2
  @obstacle :obstacle
  @all_options Keyword.keys(@default_new_options) ++ [:board, :score, :turns, :state]
  @valid_moves [:up, :down, :left, :right]

  def init(%{state: :new} = opts) do
    opts
    # |> Keyword.validate!(@default_new_options)
    |> Map.merge(%{
      board: starting_board({opts.num_rows, opts.num_cols}, opts.starting_number, @obstacles),
      score: 0,
      turns: 0,
      state: :running
    })
    |> init()
  end

  def init(opts) do
    %{
      board: opts.board,
      score: opts.score,
      turns: opts.turns,
      state: opts.state,
      turn_start_number: opts.turn_start_number,
      winning_number: opts.winning_number
    }
  end

  def tick(%{state: :running} = game, move) when move in @valid_moves do
    apply_move(game, move)
  end

  defp starting_board({num_rows, num_cols}, starting_number, num_obstacles) do
    empty_cells =
      for row <- 1..num_rows, col <- 1..num_cols, into: %{}, do: {{row, col}, nil}

    board = %{cells: empty_cells, dimensions: {num_rows, num_cols}}

    board = add_value(board, starting_number)
    # TODO this will generate two obstacles when num_obstacles == 0
    Enum.reduce(1..num_obstacles, board, fn _, acc -> add_value(acc, @obstacle) end)
  end

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

  defp apply_move(%{board: board} = game, move) do
    updated_board = board |> merge_values(move) |> move_values(move)

    # Only need to update state if the board changed.
    if Map.equal?(board, updated_board) do
      game
    else
      turn_score = compute_score(board, updated_board)
      apply_turn(game, updated_board, turn_score)
    end
  end

  defp compute_score(%{cells: cells_before} = _board_before, %{cells: cells_after} = _board_after) do
    value_counts_before = cells_before |> Map.values() |> Enum.frequencies()
    value_counts_after = cells_after |> Map.values() |> Enum.frequencies()

    # Any values not present after a move must be due to merges.
    # Credit merges as the sum of all disappearing values.
    value_counts_before
    |> Enum.map(fn
      {nil, _count} ->
        0

      {value, count} ->
        difference = count - Map.get(value_counts_after, value, 0)
        if difference > 0, do: value * difference, else: 0
    end)
    |> Enum.sum()
  end

  defp apply_turn(
         %{score: score, turns: turns, turn_start_number: turn_start_number} = game,
         board,
         turn_score
       ) do
    game = %{game | board: board, turns: turns + 1, score: score + turn_score}

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
    # For each row, we run a two-pointer algorithm where:
    #
    # * Pointer #1 iterates through the row.
    # * Pointer #2 points to the latest non-empty, non-modified cell behind pointer #1.
    #
    # As #1 iterates, if its current cell is not empty and:
    #
    # * Has the same value as the cell of #2: the cell of #1 will be merged into that of #2 (the #2 cell
    #   value will be doubled and the #1 cell will be emptied) and the #2 pointer will
    #   be nullified. Or;
    # * Does not have the same value as the cell of #2: the #2 pointer
    #   is updated to point to #1 before #1 continues its iteration.
    updates =
      rows_for_move(board, move)
      |> Enum.map(fn row ->
        Enum.map(row, fn coord -> {coord, cells[coord]} end)
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

          @obstacle ->
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
