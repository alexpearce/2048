defmodule TwentyFourtyEightWeb.GameLive do
  use TwentyFourtyEightWeb, :live_view

  alias TwentyFourtyEight.Game.Game
  alias TwentyFourtyEight.Game.Manager, as: GameManager

  # Support arrows keys as well as hjkl (Vim) and wasd (gaming).
  @up_keys ["ArrowUp", "w", "k"]
  @down_keys ["ArrowDown", "s", "j"]
  @left_keys ["ArrowLeft", "a", "h"]
  @right_keys ["ArrowRight", "d", "l"]
  @known_keys @up_keys ++ @down_keys ++ @left_keys ++ @right_keys

  def render(assigns) do
    ~H"""
    <div class="cozy">
      <div class="stats">
        <div><b>Name</b> <code><%= @name %></code></div>
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

        {:ok, assign_game(socket, name)}
    end
  end

  @doc """
  Handle known key events whilst the game is running.
  """
  def handle_event("move", %{"key" => key}, %{assigns: %{name: name, state: :running}} = socket)
      when key in @known_keys do
    :ok = GameManager.tick(name, key_to_move(key))
    {:noreply, assign_game_state(socket, name)}
  end

  def handle_event("move", _params, socket), do: {:noreply, socket}

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
    <%= if is_nil(@value) do %>
      <div class="cell" style="--cell-value: 0;">&nbsp;</div>
    <% else %>
      <div class="cell" style={"--cell-value: #{@value};"}><%= @value %></div>
    <% end %>
    """
  end
end
