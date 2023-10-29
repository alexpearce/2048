defmodule TwentyFortyEightWeb.GameLive do
  use TwentyFortyEightWeb, :live_view

  alias TwentyFortyEight.Game.Game
  alias TwentyFortyEight.Game.Manager, as: GameManager

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
      <.board num_rows={@num_rows} num_cols={@num_cols} cell_values={@board} />
    </div>
    """
  end

  def mount(%{"name" => name} = _params, _session, socket) do
    case Game.get_by_slug(name) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Could not find game with ID #{name}.")
         |> redirect(to: ~p"/")}

      game ->
        # TODO change game to die after no interaction (or put similar logic in the manager?)
        {:ok, _pid} = GameManager.get_game(name, game)

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
    :ok = GameManager.tick(name, key_to_move(key))
    Phoenix.PubSub.broadcast(TwentyFortyEight.PubSub, name, {:update, name})
    {:noreply, socket}
  end

  def handle_event("move", _params, socket), do: {:noreply, socket}

  def handle_info({:update, name}, socket) do
    {:noreply, assign_game_state(socket, name)}
  end

  defp key_to_move(up) when up in @up_keys, do: :up
  defp key_to_move(down) when down in @down_keys, do: :down
  defp key_to_move(left) when left in @left_keys, do: :left
  defp key_to_move(right) when right in @right_keys, do: :right

  defp assign_game(socket, name) do
    socket
    |> assign(name: name)
    |> assign_game_state(name)
  end

  defp assign_game_state(socket, name) do
    game_state = GameManager.state(name)
    {%{cells: board, dimensions: {num_rows, num_cols}}, game_state} = Map.pop(game_state, :board)

    socket
    |> assign(num_rows: num_rows, num_cols: num_cols, board: board)
    |> assign(game_state)
  end

  defp status_message(:running), do: ""
  defp status_message(:won), do: "You won!"
  defp status_message(:exhausted), do: "Game over!"

  defp board(assigns) do
    ~H"""
    <div
      class="board"
      style={"grid-template-columns: repeat(#{@num_cols}, 1fr);"}
      phx-window-keyup="move"
    >
      <.cell :for={cell <- cell_indicies(@num_rows, @num_cols)} value={@cell_values[cell]} />
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
        <div class="cell" style="--cell-value: 0;">&nbsp;</div>
      <% :obstacle -> %>
        <div class="cell" style="--cell-value: 0;">X</div>
      <% _ -> %>
        <div class="cell" style={"--cell-value: #{@value};"}><%= @value %></div>
    <% end %>
    """
  end
end
