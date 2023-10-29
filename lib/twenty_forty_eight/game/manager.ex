defmodule TwentyFortyEight.Game.Manager do
  use GenServer, restart: :transient

  alias TwentyFortyEight.Game.{Board, Engine, Game}

  @registry TwentyFortyEight.Game.Registry
  @supervisor TwentyFortyEight.Game.Supervisor

  def get_game(name, %Game{} = game) when is_binary(name) do
    case Registry.lookup(@registry, name) do
      [{pid, _value}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(@supervisor, {__MODULE__, {name, game}})
    end
  end

  def tick(name, move) do
    GenServer.call(via_tuple(name), {:tick, move})
  end

  def state(name) do
    GenServer.call(via_tuple(name), :state)
  end

  def start_link({name, game}) do
    GenServer.start_link(__MODULE__, game, name: via_tuple(name))
  end

  @impl true
  def init(%Game{} = game) do
    Process.flag(:trap_exit, true)
    {:ok, create_or_restore_engine(game)}
  end

  @impl true
  def handle_call({:tick, move}, _from, game) do
    {:reply, :ok, Engine.tick(game, move)}
  end

  @impl true
  def handle_call(:state, _from, game) do
    response = Map.take(game, [:board, :score, :turns, :state])
    {:reply, response, game}
  end

  @impl true
  def handle_info({:EXIT, from, reason}, game) do
    IO.puts("Trapped exit from #{inspect(from)} because #{inspect(reason)}")
    {:stop, reason, game}
  end

  defp via_tuple(name) do
    {:via, Registry, {@registry, name}}
  end

  defp create_or_restore_engine(%Game{state: :new, board: nil} = game) do
    board = Board.init(game.num_rows, game.num_cols, game.starting_number, game.num_obstacles)
    opts = [turn_start_number: game.turn_start_number, winning_number: game.winning_number]

    Engine.init(board, opts)
  end

  defp create_or_restore_engine(game) do
    board = %Board{cells: game.board, num_rows: game.num_rows, num_cols: game.num_cols}

    state = %{
      board: board,
      score: game.score,
      turns: game.turns,
      state: game.state,
      turn_start_number: game.turn_start_number,
      winning_number: game.winning_number
    }

    Engine.restore(state)
  end
end
