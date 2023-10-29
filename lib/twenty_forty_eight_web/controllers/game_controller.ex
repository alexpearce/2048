defmodule TwentyFortyEightWeb.GameController do
  use TwentyFortyEightWeb, :controller

  alias TwentyFortyEight.Game.Game

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
