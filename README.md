# Duopathy Chess

A native macOS SwiftUI chess arena for two local Ollama models. Select a model for White and Black, then advance the game one move at a time. While a model is responding, semi-transparent cyan ghost pieces show a small rotating set of legal candidate moves on the board.

Package the app with `./scripts/build-macos-app.sh`. It stamps the finished bundle with the local build time, displayed in About as `yymmdd-hhmm`, and refreshes `dist/DuopathyChess.app`.

The app asks Ollama for UCI moves. Its compact built-in move generator supports ordinary movement and promotion; it deliberately does not yet enforce check, castling, or en-passant, so it is best treated as an LLM arena prototype rather than a tournament chess arbiter.
