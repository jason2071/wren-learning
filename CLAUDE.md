# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **WrenAI semantic-layer project** over PostgreSQL — not an application codebase. There is no build/test pipeline; `go.mod` is vestigial (no Go source). The "code" is YAML/Markdown config that Wren compiles into a query layer. The repo doubles as a teaching demo: `demo_db/seed_wren_demo.sql` seeds data with 4 intentional traps (dead `customers_v1` vs `customers_v2`, integer `status` codes, sensitive columns, `created_at` vs `paid_at`) to contrast raw SQL against Wren.

## Environment setup (required before any `wren` command)

```bash
source ~/.venvs/wren/bin/activate          # Wren installed in this venv
export $(grep -v '^#' .env | xargs)        # load PG_* — connection.yml resolves ${PG_*} from env
```

`.env` is gitignored (holds real DB credentials). `.env.example` is the template — `cp .env.example .env` then fill in.

## Core workflow — the build/index cycle

Config files are **source**; `target/mdl.json` and `.wren/memory/` are **generated** (both gitignored). After editing config you MUST regenerate, or queries run against stale context:

```bash
wren context build                          # after editing models/*.yml or relationships.yml → recompiles target/mdl.json
wren context build && wren memory index     # after editing instructions.md or queries.yml → also re-indexes memory
```

## Common commands

```bash
wren --sql "SELECT COUNT(*) FROM customers" -o table       # run SQL using MODEL names (not real tables)
wren dry-plan --sql "SELECT first_name FROM customers"     # show expanded SQL (customers → public.customers_v2) without hitting DB
wren dry-run  --sql "..."                                  # validate against DB, no rows returned
wren memory recall --query "ลูกค้ามีกี่คน"                  # find nearest stored NL↔SQL pair (lower distance = closer)
wren memory fetch  --query "..."                           # show context the agent would pull
wren memory store --nl "..." --sql "..."                   # save a new NL↔SQL pair
wren profile list / debug / switch <name>                  # manage DB profiles (stored globally in ~/.wren/profiles.yml)
```

Seed the demo DB (first time): `psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" -f demo_db/seed_wren_demo.sql`

## Architecture — how the layer fits together

Query against **model names**, never raw tables. The semantic layer is four cooperating pieces:

- **`models/<name>/metadata.yml`** — each defines one model. The `name:` is the queryable alias; `table_reference.table` is the real table. Key indirection: model `customers` maps to real table `customers_v2` (so the dead `customers_v1` is unreachable). Only listed `columns:` are visible to the agent — omitting a column is the masking mechanism (e.g. `national_id` is intentionally absent).
- **`relationships.yml`** — declares joins (`order_customers`: orders→customers MANY_TO_ONE). Lets cross-table questions resolve without hand-written JOINs.
- **`instructions.md`** — business semantics SQL can't express: what "active customer"/"revenue"/"สมัครสมาชิก" mean, and the `status` integer codes (1=pending, 2=paid, 3=shipped, 4=refunded, 5=cancelled). Both humans and the LLM read this. **When a definition here changes, the meaning of generated SQL changes** — treat it as load-bearing.
- **`queries.yml`** — curated NL↔SQL pairs that seed `memory recall`. Add a pair here (then re-index) to make a recurring question resolve accurately. This is the git-tracked source of truth for memory, since `.wren/memory/` itself is gitignored.

`wren_project.yml` ties it together (`catalog: wren`, `schema: public`, `data_source: postgres`, bound `profile`). `connection.yml` defines the datasource with `${PG_*}` placeholders.

## Conventions

- Filter revenue/active queries by `status = 2`; use `paid_at` (not `created_at`) for payment-time windows; `created_at` is registration time. These mirror `instructions.md` — keep the two in sync.
- Never edit `target/mdl.json` by hand (regenerate via `context build`).
- Domain docs live in `docs/` (concept guide → playbook → reference). README maps them.
