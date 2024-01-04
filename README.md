# TwentyFortyEight

A multiplayer version of [2048](https://play2048.co/) built using Elixir/Phoenix.

Available to play at https://apearwin-2048.fly.dev/.

## Development

A recent Elixir version and a running PostgreSQL instance are required for development.
The simplest way to acquire these is via the provided [Nix](https://nixos.org/) flake; if you have [direnv](https://direnv.net/) installed run `direnv allow` and a development environment will be automatically available in your shell.
PostgreSQL can be started in the foreground with `devenv up`.

Run `mix setup` to install Elixir dependencies and initialise the database.

Finally, run `mix phx.server` to start the development server.

## Gameplay

The homepage lets you choose what kind of 2048 game you'd like to play, including:

- Board dimensions (number of rows and columns);
- How many obstacles to place on the board;
- Which numbers are placed on the board initially and during turns;
- What number is required to win.

After starting the game, you can copy the URL and share it with others (or open a separate browser tab to simulate another player).
All players sharing a game can make moves in any order, and other players will see those moves in real time.

Up, down, left, and right movements are supported via the arrow keys, the hjkl keys, and the wasd keys.
Playing on mobile isn't supported.

## Code structure

The core gameplay runtime is independent of Phoenix and can in principle be driven by other interfaces, e.g. `iex` or a CLI client.
The runtime is under the `TwentyFortyEight.Game` namespace.

- `TwentyFortyEight.Game.Board`: Stores the board size and individual cell values, and encapsulates the business logic of how moves affect the board and whether a board is unsolvable.
- `TwentyFortyEight.Game.Engine`: Operates on the full game state, including the board, number of turns, score, and whether the game has been won or lost.
- `TwentyFortyEight.Game.Manager`: A layer between an `Engine` and the database, providing persistence and retrieval of games.
- `TwentyFortyEight.Game.Game`: Persistence schema for storing game state to the database.
- `TwentyFortyEight.Game.ManagerServer`: A `GenServer` which passes messages between a `Manager` it holds and its own clients. It will shut down after several minutes of inactivity, triggering database persistence to allow subsequent restarts to pick up from where the game was left.

Phoenix components are under the `TwentyFortyEightWeb` namespace.

- `TwentyFortyEightWeb.GameController`: Presents the new-game form and handles its submission.
- `TwentyFortyEightWeb.GameLive`: A LiveView which creates or connects to `Manager` instances. It requests game state from the manager to display it, forwards key presses to the manager, and uses a PubSub topic for synchronising updates between players.

Finally, there's a bunch of Phoenix boilerplate I haven't tidied up!
