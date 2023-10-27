defmodule TwentyFourtyEightWeb.GameController do
  use TwentyFourtyEightWeb, :controller

  alias TwentyFourtyEight.Game.Game

  def new(conn, _params) do
    changeset = Game.changeset(%{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, params) do
    changeset = Game.changeset(params["game"])

    case Game.insert(changeset) do
      {:ok, game} -> redirect(conn, to: ~p"/#{game.slug}")
      {:error, changeset} -> render(conn, :new, changeset: changeset)
    end
  end
end
