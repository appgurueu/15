# 15

The [15](https://en.wikipedia.org/wiki/15_puzzle) puzzle.

## App

Allows creating, playing & editing puzzles. Includes a solver. Puzzles can be copied to and pasted from clipboard in hex format.
You can click on the neighboring buttons of the blank spots or use WASD or slide gestures to play.

Web (JS) build won't work since the board representation requires 64-bit ints;
might work with the experimental WASM build mode.

## CLI

A simple CLI for the solver is at `cli_solve.dart`.

Run using `dart run cli_solve.dart <hex board>`,
compile using `dart compile exe cli_solve.dart -o solve` (and then run using `./solve <hex board>`).

The output is a sequence of puzzle states, from the given problem to the winning board, as hex, with newlines inserted for better readability.

The hex format is simply a hex string of the hex digits of the 16 tiles; the blank tile is assigned 0. The winning board is stored as `123456789abcdef0` using this format. Whitespace is not allowed.
