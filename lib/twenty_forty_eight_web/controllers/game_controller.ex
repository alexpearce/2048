defmodule TwentyFortyEightWeb.GameController do
  use TwentyFortyEightWeb, :controller

  alias TwentyFortyEight.Game.Game

  def new(conn, _params) do
    changeset = Game.create_changeset(%{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"game" => attrs} = _params) do
    changeset = Game.create_changeset(attrs)

    case Game.insert(changeset) do
      {:ok, game} -> redirect(conn, to: ~p"/#{game.slug}")
      {:error, changeset} -> render(conn, :new, changeset: changeset)
    end
  end
end
