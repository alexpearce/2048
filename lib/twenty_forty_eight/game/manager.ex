defmodule TwentyFortyEight.Game.Manager do
  use GenServer, restart: :transient

  alias TwentyFortyEight.Game.Engine

  @registry TwentyFortyEight.Game.Registry
  @supervisor TwentyFortyEight.Game.Supervisor

  def get_game(name, state) when is_binary(name) do
    case Registry.lookup(@registry, name) do
      [{pid, _value}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(@supervisor, {__MODULE__, {name, state}})
    end
  end

  def tick(name, move) do
    GenServer.call(via_tuple(name), {:tick, move})
  end

  def state(name) do
    GenServer.call(via_tuple(name), :state)
  end

  def start_link({name, state}) do
    GenServer.start_link(__MODULE__, state, name: via_tuple(name))
  end

  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, Engine.init(state)}
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
end
