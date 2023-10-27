defmodule TwentyFourtyEightWeb.GameHTML do
  use TwentyFourtyEightWeb, :html

  def new(assigns) do
    ~H"""
    <div class="cozy">
      <.simple_form :let={f} for={@changeset} action={~p"/"}>
        <.input field={f[:num_rows]} type="select" options={1..6} label="Number of rows" />
        <.input field={f[:num_cols]} type="select" options={1..6} label="Number of columns" />
        <.input field={f[:starting_number]} type="select" options={[1, 2, 4]} label="First number" />
        <.input
          field={f[:turn_start_number]}
          type="select"
          options={[1, 2, 4]}
          label="Number added at each turn"
        />
        <.input
          field={f[:winning_number]}
          type="select"
          options={[1024, 2048]}
          label="Number required to win"
        />
        <:actions>
          <.button>Start game</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
