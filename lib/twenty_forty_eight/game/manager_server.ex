defmodule TwentyFortyEight.Game.ManagerServer do
  @moduledoc """
  Process wrapper around a `Manager`.

  The process times out 10 minutes after receiving the last message. The manager
  is instructed to persist the game state if the process times out or if a
  linked process exits.
  """
  use GenServer, restart: :transient

  alias TwentyFortyEight.Game.Manager

  @registry TwentyFortyEight.Game.Registry
  @supervisor TwentyFortyEight.Game.Supervisor
  # Shutdown the server after 10 minutes to avoid dangling processes.
  @default_timeout 10 * 60 * 1_000

  @doc """
  Ensure a server is running for the game named `name`.
  """
  def start(%Manager{name: name} = manager, opts \\ []) do
    case Registry.lookup(@registry, name) do
      [{pid, _value}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(@supervisor, {__MODULE__, {manager, opts}})
    end
  end

  def start_link({%Manager{name: name} = manager, opts}) do
    GenServer.start_link(__MODULE__, {manager, opts}, name: via_tuple(name))
  end

  @doc """
  Increment the game by one move.
  """
  def tick(name, move) do
    GenServer.call(via_tuple(name), {:tick, move})
  end

  @doc """
  Return the `Manager` wrapped by this server.
  """
  def manager(name) do
    GenServer.call(via_tuple(name), :manager)
  end

  @impl true
  def init({manager, opts}) do
    Process.flag(:trap_exit, true)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    {:ok, %{manager: manager, timeout: timeout}, timeout}
  end

  @impl true
  def handle_call({:tick, move}, _from, state) do
    manager = Manager.tick(state.manager, move)
    state = %{state | manager: manager}
    {:reply, :ok, state, state.timeout}
  end

  @impl true
  def handle_call(:manager, _from, state) do
    {:reply, state.manager, state, state.timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_info({:EXIT, _from, reason}, state) do
    {:stop, reason, state}
  end

  @impl true
  def terminate(_reason, state) do
    Manager.save(state.manager)
  end

  defp via_tuple(name) do
    {:via, Registry, {@registry, name}}
  end
end
