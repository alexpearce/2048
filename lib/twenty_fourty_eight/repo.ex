defmodule TwentyFourtyEight.Repo do
  use Ecto.Repo,
    otp_app: :twenty_fourty_eight,
    adapter: Ecto.Adapters.Postgres
end
