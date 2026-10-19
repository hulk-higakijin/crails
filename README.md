# Crails

A stock Rails 8.1 app used to experiment with compiling Rails to a native
binary through [Roundhouse](https://rubys.github.io/roundhouse/) (spinel
target) and [Spinel](https://github.com/matz/spinel) / `spin`.

## Dependencies

- Ruby from `.ruby-version` (currently `ruby-4.0.6`) with bundler.
  Any Ruby 4.x close to it works; the experiment ran on 4.0.7.
- Compilation tools, all on `PATH`:
  - `roundhouse` — transpiles the Rails app to the spinel target.
    Verified with `roundhouse 2026.9.18`.
  - `spinel` and `spin` — ahead-of-time compiler and project tool.
    Verified with `spinel 112bae85c1a2 (2026.09.12)`.
  - `make` — builds the emitted tree (`make assets`, `make build`).
- C toolchain plus SQLite headers (`libsqlite3-dev`) — the binary links
  `-lsqlite3`.
- jemalloc headers (`libjemalloc-dev`) — the emitted `spin.toml` asks for
  the jemalloc allocator, so the headers must be present to link.
- Node.js 18+ — only for the emitted tree's Playwright end-to-end suite.
  Not needed for `bin/rails compile`.

## Setup

```sh
bundle install
bin/rails db:prepare
bin/rails test
```

`bin/rails test` currently runs 0 tests; the suite is green and CI runs
it on every pull request along with RuboCop, Brakeman, bundler-audit,
and importmap audit.

## Compiling

```sh
bin/rails compile
```

This is a Rake task (`lib/tasks/compile.rake`) that runs the whole
pipeline for you:

1. `roundhouse check --continue .` — analyzes the app and prints the gem
   census plus diagnostics. It passes clean here: 23 gems
   (9 framework, 1 modeled, 13 infrastructure, 0 unknown).
2. `roundhouse --target spinel . -o out/spinel` — emits the lowered app
   (about 244 files) into `out/spinel`. The directory is git-ignored and
   regenerated on every run.
3. `bundle install` inside `out/spinel` — installs the emitted tree's own
   gems (needed before assets, since asset rules locate gem files through
   bundler).
4. `make assets` inside `out/spinel` — copies the stylesheet, importmap
   pins, and gem-bundled JS into `static/assets/`. The binary serves
   these at `/assets/*` and must be launched from the emitted root so it
   finds `static/`.
5. `make build` inside `out/spinel` — runs `spin build`, producing the
   native binary (about 1.6 MB).

Environment variables change the behavior:

- `OUT=out/spinel` — where the transpiled tree goes.
- `BIN_NAME=crails` — file name of the reported binary. It defaults to
  the app directory name. Roundhouse's spinel target always emits
  `bin/blog.rb` → `build/blog` (named after its own scaffold, not this
  app), so the task copies the built binary to `build/<BIN_NAME>` and
  reports that path.
- `SKIP_CHECK=1` — skip step 1.
- `SKIP_ASSETS=1` — skip step 4.
- `SKIP_BUILD=1` — skip step 5 (emit and assets only).

## Running the binary

```sh
cd out/spinel && ./build/crails
```

Open `http://localhost:3000`. Useful variables:

- `PORT` — listen port (default 3000).
- `WORKERS` — prefork processes (default 1); `SPINEL_WORKERS` caps OS workers.
- `BLOG_DB` — SQLite file (default `storage/development.sqlite3`).

## Known gaps

This plain app does not yet compile to a runnable binary end to end:

- No root route. The emitted `main.rb` calls `RouteTable.root`, but the
  emitted `config/routes.rb` only defines it when the source app has a
  root. Without one, `make build` fails with
  `unsupported call ... (CallNode 'root')`.
- No app tables. The emitted `config/schema.rb` comes out empty when the
  source schema has no application tables, and the binary crashes at boot
  with `undefined method 'each' for unknown` at
  `Schema.statements.each`.
- `/up` is not modeled. Even with a root added, `GET /up` returns 500 in
  the binary (`uninitialized constant HealthController`) while CRuby
  returns 200.

Adding an explicit root route plus one string/text-backed model is enough
to get a 200 on `/`; that shape was verified during the experiment but is
deliberately not part of this tree.
