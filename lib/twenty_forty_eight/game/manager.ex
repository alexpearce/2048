defmodule TwentyFortyEight.Game.Manager do
  @moduledoc """
  Manage an `Engine` and its persistence to the database.

  An `Engine` is the primary interface to a game instance, whereas a `Game` is
  the primary mechanism for persisting that instance. A `Manager` provides a
  layer above these two, loading a `Game` to create an `Engine` and saving an
  `Engine` to the DB as a `Game`.
  """
  @enforce_keys [:name, :engine]
  defstruct [:name, :engine]

  alias TwentyFortyEight.Game.{Board, Engine, Game}

  @doc """
  Return a manager for `Game` named `name` that exists in the DB.

  If no such game exists return `{:error, :not_found}`.
  """
  def get(name) do
    with {:ok, game} <- get_game(name) do
      {:ok, create_manager(game)}
    end
  end

  @doc """
  Increment the `Engine` by one move.
  """
  def tick(%__MODULE__{} = manager, move) do
    engine = Engine.tick(manager.engine, move)
    %__MODULE__{manager | engine: engine}
  end

  @doc """
  Persist the `Engine` as a `Game` to the DB.
  """
  def save(%__MODULE__{} = manager) do
    with {:ok, %Game{} = game} <- get_game(manager.name),
         {:ok, %Game{}} <- Game.update(game, dump_engine(manager.engine)) do
      :ok
    end
  end

  defp get_game(name) do
    case Game.get_by_slug(name) do
      nil ->
        {:error, :not_found}

      game ->
        {:ok, game}
    end
  end

  defp create_manager(%Game{} = game) do
    engine = load_engine(game)

    %__MODULE__{
      name: game.slug,
      engine: engine
    }
  end

  defp load_engine(%Game{state: :new, board: nil} = game) do
    board = Board.init(game.num_rows, game.num_cols, game.starting_number, game.num_obstacles)
    opts = [turn_start_number: game.turn_start_number, winning_number: game.winning_number]

    Engine.init(board, opts)
  end

  defp load_engine(game) do
    state = %{
      board: load_board(game),
      score: game.score,
      turns: game.turns,
      state: game.state,
      turn_start_number: game.turn_start_number,
      winning_number: game.winning_number
    }

    Engine.restore(state)
  end

  defp dump_engine(engine) do
    %{
      board: dump_board(engine.board),
      score: engine.score,
      turns: engine.turns,
      state: engine.state,
      turn_start_number: engine.turn_start_number,
      winning_number: engine.winning_number
    }
  end

  defp load_board(%Game{board: %{"cells" => cell_values}} = game) do
    # Decode the cells from JSON serialisation as a Board.
    coordinates = for row <- 1..game.num_rows, col <- 1..game.num_cols, do: {row, col}

    cell_values =
      Enum.map(cell_values, fn
        nil -> nil
        "obstacle" -> :obstacle
        value when is_integer(value) -> value
      end)

    %Board{
      cells: Enum.zip(coordinates, cell_values) |> Enum.into(%{}),
      num_rows: game.num_rows,
      num_cols: game.num_cols
    }
  end

  defp dump_board(%Board{cells: cells} = board) do
    # Encode the cells for JSON serialisation.
    # Note that we omit the dimensions as these are already stored on the Game.
    cell_values = for row <- 1..board.num_rows, col <- 1..board.num_cols, do: cells[{row, col}]
    %{cells: cell_values}
  end
end
