defmodule TwentyFortyEight.Repo do
  use Ecto.Repo,
    otp_app: :twenty_forty_eight,
    adapter: Ecto.Adapters.Postgres
end
