defmodule TwentyFourtyEightWeb.GameLive do
  use TwentyFourtyEightWeb, :live_view

  alias TwentyFourtyEight.Game.Manager, as: GameManager

  def render(assigns) do
    ~H"""
    <div class="container bg-slate-100">
      Name: <%= @name %>
      Turn number: <%= @turns %>
      Score: <%= @score %>
      <!--
      Possible grid sizes:
      grid-cols-1 grid-cols-2 grid-cols-3 grid-cols-4 grid-cols-5 grid-cols-6
      grid-rows-1 grid-rows-2 grid-rows-3 grid-rows-4 grid-rows-5 grid-rows-6
      -->
      <div class={"grid grid-cols-#{@num_cols} gap-4 h-96 text-3xl p-6"} phx-window-keyup="move">
        <%= for row <- 1..@num_rows do %>
          <%= for col <- 1..@num_cols do %>
            <%= if is_nil(@board[{row, col}]) do %>
              <div class="flex justify-center items-center bg-slate-200 border-2 border-slate-300 rounded-lg">&nbsp;</div>
            <% else %>
              <div class="flex justify-center items-center bg-slate-300 border-2 border-slate-400 rounded-lg"><%= @board[{row, col}] %></div>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(%{"name" => name} = _params, _session, socket) do
    # TODO this is called twice, once at GET and once at WS connection.
    # no need to create two games! just need to make sure assigns are
    # filled in with placeholders
    {:ok, pid} = GameManager.new_game(name)
    Process.link(pid)

    socket = socket
    |> assign_game(name)
    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    name = generate_name()
    {:ok, push_navigate(socket, to: "/#{name}")}
  end

  def handle_event("move", %{"key" => key}, %{assigns: %{name: name}} = socket) when key in ~w(h j k l) do
    :ok = GameManager.tick(name, key_to_move(key))
    {:noreply, assign_game_state(socket, name)}
  end

  def handle_event("move", params, socket) do
    {:noreply, socket}
  end

  defp key_to_move("h"), do: :left
  defp key_to_move("j"), do: :down
  defp key_to_move("k"), do: :up
  defp key_to_move("l"), do: :right

  defp generate_name do
    ?a..?z
    |> Enum.take_random(6)
    |> List.to_string()
  end

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
end