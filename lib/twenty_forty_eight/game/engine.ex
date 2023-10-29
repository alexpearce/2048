defmodule TwentyFortyEight.Game.Engine do
  alias TwentyFortyEight.Game.Board

  @doc """
  Return engine state for a new game.

  The board is assumed to be in a state where a valid move can be made.
  """
  def init(%Board{} = board, opts) do
    state = %{
      board: board,
      score: 0,
      turns: 0,
      state: :running,
      turn_start_number: opts[:turn_start_number],
      winning_number: opts[:winning_number]
    }

    restore(state)
  end

  @doc """
  Return engine state loaded from a previous engine.
  """
  def restore(state) do
    %{
      board: state.board,
      score: state.score,
      turns: state.turns,
      state: state.state,
      turn_start_number: state.turn_start_number,
      winning_number: state.winning_number
    }
  end

  @doc """
  Increment the game by one move.
  """
  def tick(%{state: :running} = game, move) do
    apply_move(game, move)
  end

  defp apply_move(%{board: board} = game, move) do
    updated_board = Board.apply_move(board, move)

    if Board.equal?(board, updated_board) do
      game
    else
      turn_score = compute_score(board, updated_board)
      update_game(game, updated_board, turn_score)
    end
  end

  defp compute_score(%{cells: cells_before} = _board_before, %{cells: cells_after} = _board_after) do
    value_counts_before = cells_before |> Map.values() |> Enum.frequencies()
    value_counts_after = cells_after |> Map.values() |> Enum.frequencies()

    # Any values not present after a move must be due to merges.
    # Credit merges as the sum of all disappearing values.
    value_counts_before
    |> Enum.map(fn
      {value, count} when is_integer(value) ->
        difference = count - Map.get(value_counts_after, value, 0)
        if difference > 0, do: value * difference, else: 0

      {_value, _count} ->
        0
    end)
    |> Enum.sum()
  end

  defp update_game(game, updated_board, turn_score) do
    game
    |> Map.put(:board, updated_board)
    |> Map.update!(:turns, &(&1 + 1))
    |> Map.update!(:score, &(&1 + turn_score))
    |> maybe_put_won_state()
    |> maybe_put_next_turn_value()
    |> maybe_put_exhaustion_state()
  end

  defp maybe_put_won_state(game) do
    %{game | state: maybe_won(game)}
  end

  defp maybe_put_next_turn_value(game) do
    %{game | board: maybe_add_value(game, game.turn_start_number)}
  end

  defp maybe_put_exhaustion_state(game) do
    %{game | state: maybe_lost(game)}
  end

  defp maybe_won(game) do
    if won?(game.board, game.winning_number) do
      :won
    else
      game.state
    end
  end

  defp maybe_add_value(%{state: :running} = game, value) do
    Board.add_value(game.board, value)
  end

  defp maybe_add_value(game, _value), do: game.board

  defp won?(board, winning_number) do
    Board.has_value?(board, winning_number)
  end

  defp maybe_lost(game) do
    if Board.unsolvable?(game.board) do
      :lost
    else
      game.state
    end
  end
end
