defmodule TwentyFourtyEightWeb.GameController do
  use TwentyFourtyEightWeb, :controller

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, _params) do
    redirect(conn, to: ~p"/#{id}")
  end
end
