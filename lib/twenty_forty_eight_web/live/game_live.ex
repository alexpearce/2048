defmodule TwentyFortyEightWeb.GameLive do
  use TwentyFortyEightWeb, :live_view

  alias TwentyFortyEight.Game.Manager, as: GameManager
  alias TwentyFortyEight.Game.ManagerServer, as: GameManagerServer

  # Support arrows keys, hjkl, and wasd for movement.
  @up_keys ~w(ArrowUp w k)
  @down_keys ~w(ArrowDown s j)
  @left_keys ~w(ArrowLeft a h)
  @right_keys ~w(ArrowRight d l)
  @known_keys @up_keys ++ @down_keys ++ @left_keys ++ @right_keys

  def render(assigns) do
    ~H"""
    <div class="cozy">
      <div class="stats">
        <div><b>Name</b> <a href={~p"/#{@name}"}><code><%= @name %></code></a></div>
        <div><b>Score</b> <%= @score %></div>
        <div><b>Turns</b> <%= @turns %></div>
      </div>
      <div class="message"><%= status_message(@state) %></div>
      <.board num_rows={@num_rows} num_cols={@num_cols} cells={@cells} />
    </div>
    """
  end

  def mount(%{"name" => name} = _params, _session, socket) do
    case GameManager.get(name) do
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Could not find game with ID #{name}.")
         |> redirect(to: ~p"/")}

      {:ok, manager} ->
        {:ok, _pid} = GameManagerServer.start(manager)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(TwentyFortyEight.PubSub, name)
        end

        {:ok, assign_game(socket, name)}
    end
  end

  @doc """
  Handle known key events whilst the game is running.
  """
  def handle_event("move", %{"key" => key}, %{assigns: %{name: name, state: :running}} = socket)
      when key in @known_keys do
    socket =
      key
      |> key_to_move()
      |> case do
        {:ok, move} ->
          :ok = GameManagerServer.tick(name, move)
          Phoenix.PubSub.broadcast(TwentyFortyEight.PubSub, name, {:update, name})
          socket

        {:error, :unknown_key} ->
          put_flash(socket, :error, "Could not handle key press #{key}.")
      end

    {:noreply, socket}
  end

  def handle_event("move", _params, socket), do: {:noreply, socket}

  def handle_info({:update, name}, socket) do
    {:noreply, assign_engine(socket, name)}
  end

  defp key_to_move(up) when up in @up_keys, do: {:ok, :up}
  defp key_to_move(down) when down in @down_keys, do: {:ok, :down}
  defp key_to_move(left) when left in @left_keys, do: {:ok, :left}
  defp key_to_move(right) when right in @right_keys, do: {:ok, :right}
  defp key_to_move(_key), do: {:error, :unknown_key}

  defp assign_game(socket, name) do
    socket
    |> assign(name: name)
    |> assign_engine(name)
  end

  defp assign_engine(socket, name) do
    %GameManager{engine: engine} = GameManagerServer.manager(name)

    socket
    |> assign(Map.from_struct(engine.board))
    |> assign(engine)
  end

  defp status_message(:running), do: ""
  defp status_message(:won), do: "You won!"
  defp status_message(:lost), do: "Game over!"

  defp board(assigns) do
    ~H"""
    <div
      class="board"
      style={"grid-template-columns: repeat(#{@num_cols}, 1fr);"}
      phx-window-keyup="move"
    >
      <.cell :for={cell <- cell_indicies(@num_rows, @num_cols)} value={@cells[cell]} />
    </div>
    """
  end

  defp cell_indicies(num_rows, num_cols) do
    for row <- 1..num_rows, col <- 1..num_cols, do: {row, col}
  end

  defp cell(assigns) do
    ~H"""
    <%= case @value do %>
      <% nil -> %>
        <div class="cell" style="--cell-value: 0;"></div>
      <% :obstacle -> %>
        <div class="cell cell-obstacle" style="--cell-value: 0;"></div>
      <% _ -> %>
        <div class="cell" style={"--cell-value: #{@value};"}><%= @value %></div>
    <% end %>
    """
  end
end
