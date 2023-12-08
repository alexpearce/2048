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
  @timeout 10 * 60 * 1_000

  @doc """
  Ensure a server is running for the game named `name`.
  """
  def start(%Manager{name: name} = manager) do
    case Registry.lookup(@registry, name) do
      [{pid, _value}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(@supervisor, {__MODULE__, manager})
    end
  end

  def start_link(%Manager{name: name} = manager) do
    GenServer.start_link(__MODULE__, manager, name: via_tuple(name))
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
  def init(manager) do
    Process.flag(:trap_exit, true)
    {:ok, manager, @timeout}
  end

  @impl true
  def handle_call({:tick, move}, _from, manager) do
    manager = Manager.tick(manager, move)
    {:reply, :ok, manager, @timeout}
  end

  @impl true
  def handle_call(:manager, _from, manager) do
    {:reply, manager, manager, @timeout}
  end

  @impl true
  def handle_info(:timeout, manager) do
    handle_exit(manager)
    {:stop, :shutdown, manager}
  end

  @impl true
  def handle_info({:EXIT, _from, reason}, manager) do
    handle_exit(manager)
    {:stop, reason, manager, @timeout}
  end

  defp handle_exit(manager) do
    Manager.save(manager)
  end

  defp via_tuple(name) do
    {:via, Registry, {@registry, name}}
  end
end
