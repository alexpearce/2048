defmodule TwentyFortyEight.Game.Manager do
  use GenServer, restart: :transient

  alias TwentyFortyEight.Game.{Board, Engine, Game}

  @registry TwentyFortyEight.Game.Registry
  @supervisor TwentyFortyEight.Game.Supervisor
  # Shutdown the server after 10 minutes to avoid dangling processes.
  @timeout 10 * 60 * 1_000

  @doc """
  Ensure a manager is running for the game named `name`.

  If no game is currently running a new one is started with state loaded from
  `state`.
  """
  def start(name) when is_binary(name) do
    case Registry.lookup(@registry, name) do
      [{pid, _value}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(@supervisor, {__MODULE__, name})
    end
  end

  @doc """
  Increment the game by one move.
  """
  def tick(name, move) do
    GenServer.call(via_tuple(name), {:tick, move})
  end

  @doc """
  Return state data suitable for updating an external store.

  This state is not sufficient for restarting a game, but is intended by
  updating pre-existing state stored elsewhere (e.g. in a `%Game{}`).
  """
  def state(name) do
    GenServer.call(via_tuple(name), :state)
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  @impl true
  def init(name) do
    Process.flag(:trap_exit, true)
    game_state = Game.get_by_slug(name)
    engine = create_or_restore_engine(game_state)

    state = %{
      game: game_state,
      engine: engine
    }

    {:ok, state, @timeout}
  end

  @impl true
  def handle_call({:tick, move}, _from, state) do
    state = %{state | engine: Engine.tick(state.engine, move)}
    {:reply, :ok, state, @timeout}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, mutable_state(state), state, @timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    handle_exit(state)
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_info({:EXIT, _from, reason}, state) do
    handle_exit(state)
    {:stop, reason, state, @timeout}
  end

  defp handle_exit(%{game: game} = state) do
    {:ok, _} = persist_state(game, mutable_state(state))
  end

  defp via_tuple(name) do
    {:via, Registry, {@registry, name}}
  end

  defp mutable_state(%{engine: engine} = _state) do
    Map.take(engine, [:board, :score, :turns, :state])
  end

  defp persist_state(game, state) do
    Game.update(game, %{state | board: encode_board(state.board)})
  end

  defp encode_board(%Board{cells: cells} = board) do
    # Encode the cells for JSON serialisation.
    # Note that we omit the dimensions as these are already stored on the Game.
    cell_values = for row <- 1..board.num_rows, col <- 1..board.num_cols, do: cells[{row, col}]
    %{cells: cell_values}
  end

  defp decode_board(%Game{board: %{"cells" => cell_values}} = game) do
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

  defp create_or_restore_engine(%Game{state: :new, board: nil} = game) do
    board = Board.init(game.num_rows, game.num_cols, game.starting_number, game.num_obstacles)
    opts = [turn_start_number: game.turn_start_number, winning_number: game.winning_number]

    Engine.init(board, opts)
  end

  defp create_or_restore_engine(game) do
    state = %{
      board: decode_board(game),
      score: game.score,
      turns: game.turns,
      state: game.state,
      turn_start_number: game.turn_start_number,
      winning_number: game.winning_number
    }

    Engine.restore(state)
  end
end
