defmodule TwentyFortyEight.Game.ManagerServerTest do
  # async: false as we want exclusive access to the manager server registry.
  use TwentyFortyEight.DataCase, async: false

  alias TwentyFortyEight.Game.{Game, Manager, ManagerServer}

  describe "start/2" do
    test "returns an OK tuple containing the GenServer PID" do
      manager = create_manager()
      assert {:ok, pid} = ManagerServer.start(manager, timeout: 50)
      assert Process.alive?(pid)
    end

    test "stops the process after the timeout" do
      manager = create_manager()
      assert {:ok, pid} = ManagerServer.start(manager, timeout: 10)
      :timer.sleep(50)
      refute Process.alive?(pid)

      assert {:ok, pid} = ManagerServer.start(manager, timeout: 100)
      :timer.sleep(50)
      assert Process.alive?(pid)
      :timer.sleep(100)
      refute Process.alive?(pid)
    end

    test "starts a new process when one does not already exist" do
      manager = create_manager()
      assert {:ok, pid} = ManagerServer.start(manager, timeout: 10)
      :timer.sleep(20)
      assert {:ok, other_pid} = ManagerServer.start(manager, timeout: 10)
      assert pid != other_pid
    end

    test "returns an existing process when one already exists" do
      manager = create_manager()
      assert {:ok, pid} = ManagerServer.start(manager, timeout: 50)
      assert {:ok, ^pid} = ManagerServer.start(manager, timeout: 50)
    end
  end

  describe "manager/1" do
    test "returns the manager struct" do
      %Manager{name: name} = manager = create_manager()
      {:ok, _pid} = ManagerServer.start(manager, timeout: 50)
      assert ^manager = ManagerServer.manager(name)
    end

    test "returns an updated manager struct after a tick" do
      %Manager{name: name} = manager = create_manager()
      {:ok, _pid} = ManagerServer.start(manager, timeout: 50)
      cycle_moves(name)
      assert manager != ManagerServer.manager(name)
    end
  end

  describe "tick/1" do
    test "propagates the tick to the manager" do
      %Manager{name: name, engine: %{turns: 0}} = manager = create_manager()
      {:ok, _pid} = ManagerServer.start(manager, timeout: 50)
      cycle_moves(name)
      %Manager{engine: %{turns: turns}} = ManagerServer.manager(name)
      assert turns > 0
    end
  end

  describe "state persistence" do
    test "upon timeout" do
      %Manager{name: name, engine: %{turns: 0}} = manager = create_manager()
      {:ok, pid} = ManagerServer.start(manager, timeout: 50)
      cycle_moves(name)
      :timer.sleep(100)
      refute Process.alive?(pid)

      %{rows: [[turns, "running", board]]} =
        TwentyFortyEight.Repo.query!("SELECT turns, state, board FROM game")

      assert turns > 0
      assert %{"cells" => _cells} = board
    end

    test "when the server is stopped" do
      %Manager{name: name, engine: %{turns: 0}} = manager = create_manager()

      {:ok, pid} = ManagerServer.start(manager, timeout: 1000)
      cycle_moves(name)
      Process.exit(pid, :normal)
      :timer.sleep(100)
      refute Process.alive?(pid)

      %{rows: [[turns, "running", board]]} =
        TwentyFortyEight.Repo.query!("SELECT turns, state, board FROM game")

      assert turns > 0
      assert %{"cells" => _cells} = board
    end

    test "when a linked process is stopped" do
      %Manager{name: name, engine: %{turns: 0}} = manager = create_manager()

      spawn_pid =
        spawn(fn ->
          {:ok, _pid} = ManagerServer.start_link({manager, [timeout: 1000]})
          cycle_moves(name)
        end)

      :timer.sleep(100)
      refute Process.alive?(spawn_pid)

      %{rows: [[turns, "running", board]]} =
        TwentyFortyEight.Repo.query!("SELECT turns, state, board FROM game")

      assert turns > 0
      assert %{"cells" => _cells} = board
    end
  end

  defp create_manager do
    {:ok, game} = Game.create_changeset(%{}) |> Game.insert()

    {:ok, manager} = Manager.get(game.slug)

    manager
  end

  defp cycle_moves(name) do
    :ok = ManagerServer.tick(name, :up)
    :ok = ManagerServer.tick(name, :down)
    :ok = ManagerServer.tick(name, :left)
    :ok = ManagerServer.tick(name, :right)
  end
end
