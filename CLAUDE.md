# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```bash
# Local dev server (no SAM/Docker needed — same code path as Lambda)
set -a; source .env; set +a
python run_local.py              # http://localhost:8000

# Pre-deployment validation (no DB needed — validates routing + request parsing)
python smoke_test.py

# Deploy
sam build
sam deploy --config-env staging  # or production
```

## Architecture

**Single Lambda, regex router.** All traffic hits one Lambda. `routing.py` dispatches to service methods via a ROUTES table of `(method, regex, handler)` tuples. No framework — hand-rolled.

**Layered per domain.** Each domain under `functions/` (wards, properties, stats, alerts, chat, admin) has:
- `*_modal.py` — SQL queries via SQLAlchemy text, returns raw dicts
- `*_service.py` — business logic, orchestration, Bedrock calls

**Request flow:**
```
API Gateway → lambda_function.handler()
  → parse_request()          # request_handler.py: JSON, query params, or multipart CSV
  → routing.dispatch()
  → Service.method(obj, conn)
  → returns (status_str, data_dict)
```

Exceptions map to HTTP codes: `LookupError` → 404, `ValueError` → 400, anything else → 500.

## Environment Variables

Copy `.env.example` to `.env`. Required:

| Var | Notes |
|-----|-------|
| `DB_URL` | `mysql+pymysql://user:pass@host:3306/gvmc` |
| `S3_BUCKET` | `gvmc-sw14-data` |
| `BEDROCK_REGION` | `us-east-1` — Llama only available there, not ap-south-1 |
| `BEDROCK_EXPLAIN_MODEL_ID` | `us.meta.llama4-scout-17b-instruct-v1:0` |
| `BEDROCK_CHAT_MODEL_ID` | `us.meta.llama3-3-70b-instruct-v1:0` |
| `PIPELINE_EC2_INSTANCE_ID` | Optional; if unset, `/admin/refresh` only updates DB status |

Bedrock models must use `us.*` cross-region inference profile IDs — bare model IDs fail with on-demand throughput errors.

## Database

Apply schema + seed data: `mysql -h <host> -u <user> -p gvmc < schema.sql`

Key design decisions:
- `ai_explanation` cached in `properties` table (computed on first `GET /api/properties/{id}`, then stored)
- `admin_config` table stores ad-hoc key/value pairs including Bedrock commissioner brief cache (10-min TTL) and runtime config (`data_mode`, `pipeline_status`, `ndbi_threshold`)
- Revenue estimate = `SUM(area_sqm × rate)` for pending/underassessed only; rate is 80/sqm for new_build, 40/sqm for change_of_use

## Shared Modules

**`shared/db.py`** — SQLAlchemy singleton engine. Use `get_connection()` context manager; commits on exit, rolls back on exception. Pool tuned for Lambda cold starts (`pool_size=1`).

**`shared/s3_client.py`** — `presigned_get(key)`, `upload_json(key, data)`, `upload_csv(prefix, rows)`.

**`shared/bedrock_client.py`** — All Bedrock calls here. Every public function (`explain_property`, `commissioner_brief`, `chat_reply`) falls back to a markdown template on any Bedrock error so the API never breaks.

## CI/CD

GitHub Actions (`.github/workflows/deploy.yml`) runs `sam build && sam deploy --config-env staging` on push to `main`. Required secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `S3_BUCKET`.

## Seeding GeoJSON

After initial deploy, run:
```bash
DB_URL=... S3_BUCKET=gvmc-sw14-data AWS_REGION=ap-south-1 python seed/seed_geojson.py
```
Uploads ~40m polygon squares around each property to `geojson/ward-{id}.json` in S3.
