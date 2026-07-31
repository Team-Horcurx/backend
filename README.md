# GVMC Change-Detection Engine — Backend

Python 3.12 AWS Lambda (single function, hand-rolled regex router) + API Gateway + RDS MySQL + S3 + Bedrock.
Serves the exact REST contract the already-built React frontend (`../frontend`) expects — see
`API contract` below. No authentication (public demo API, per the project plan).

Full design rationale and the ordered deployment runbook live in the approved plan at
`C:\Users\HP\.claude\plans\reference-backend-ok-by-using-toasty-hopper.md`. This file is the
quick-reference version.

## Structure

```
lambda_function.py   entrypoint — CORS + raw-JSON responses (no {status,data} envelope)
request_handler.py   merges query params + JSON/multipart body (no auth)
routing.py           regex ROUTES table -> dispatch_rest
shared/               db.py (SQLAlchemy engine), s3_client.py (presigned URLs), bedrock_client.py (AI)
wards/ properties/ stats/ alerts/ chat/ admin/    one *_modal.py (SQL) + *_service.py (logic) per domain
schema.sql            DDL + seed data mirroring frontend/src/mocks/data/*.js exactly
seed/seed_geojson.py  uploads placeholder ward polygons to S3 post-deploy
template.yaml         SAM stack (single Lambda, /{proxy+} ANY+OPTIONS, BinaryMediaTypes for CSV upload)
run_local.py          local dev server, no SAM/Docker needed
smoke_test.py         pre-flight check: routing table + request parsing, no DB needed
```

## API contract (raw JSON — axios reads `response.data` directly, no wrapper)

| Method | Path | Notes |
|---|---|---|
| GET | `/api/wards` | `[{id, name, bbox, geojson_s3, detection_count}]` |
| GET | `/api/wards/{wardId}/changes` | `{presigned_url}` → S3 GeoJSON |
| GET | `/api/wards/{wardId}/unassessed?type=&status=` | property list, filterable |
| GET | `/api/wards/{wardId}/alerts` | `[{id, severity, text, ward_id, created_at}]` |
| GET | `/api/properties/{id}` | property + `ai_explanation` (Bedrock, cached) |
| POST | `/api/properties/{id}/verify` | `{status, notes, updated_by}` → `{status}` |
| GET | `/api/stats?ward_id=` | aggregate counts + revenue estimate + admin config |
| GET | `/api/stats/all-wards` | per-ward breakdown + `ai_brief` (Bedrock, cached 10 min) |
| POST | `/api/alerts/export` | `{presigned_url}` → CSV in S3 |
| POST | `/api/chat` | `{message}` → `{response}` |
| POST | `/api/admin/upload-csv` | multipart CSV → `{properties_imported}` |
| POST | `/api/admin/db-config` | arbitrary config upsert |
| POST | `/api/admin/refresh` | `{triggered: true}` |

## Deploy — single-take runbook

1. **AWS prep (one-time, manual):**
   - RDS MySQL 8 `db.t3.micro` in `ap-south-1`, publicly accessible, security group inbound rule on port 3306
     open to Lambda (Lambda's outbound IP isn't fixed without a NAT/VPC setup, so a CIDR locked to one dev's
     IP won't work — see Known tradeoffs).
   - S3 bucket `gvmc-sw14-data`.
   - Bedrock: `meta.llama4-scout-17b-instruct-v1:0` and `meta.llama3-3-70b-instruct-v1:0` are **not** available
     in `ap-south-1` (confirmed via `aws bedrock list-foundation-models`) — only in regions like `us-east-1`,
     which is why `BEDROCK_REGION` defaults there. Both models also require the **cross-region inference
     profile id**, not the bare model id, for on-demand invocation (`us.meta.llama4-scout-17b-instruct-v1:0` /
     `us.meta.llama3-3-70b-instruct-v1:0` — find them with
     `aws bedrock list-inference-profiles --region us-east-1`); invoking the bare id fails with
     "on-demand throughput isn't supported". `.env.example`/`template.yaml` already default to the correct
     `us.*` ids. New AWS accounts often start with a very low Bedrock on-demand tokens-per-day quota — if you
     hit `ThrottlingException: Too many tokens per day`, request a quota increase in Service Quotas before the
     demo, don't just retry. If model access isn't approved in time at all, swap in an Anthropic Claude model
     id on Bedrock instead (near-universal availability) via `BEDROCK_EXPLAIN_MODEL_ID`/`BEDROCK_CHAT_MODEL_ID`
     — note `bedrock_client.py`'s `_invoke_llama` request/response shape is Llama-specific, so a Claude swap
     needs its Converse-API body format instead.

2. **Apply schema:**
   ```
   mysql -h <rds-host> -u <user> -p gvmc < schema.sql
   ```
   (create the `gvmc` database first: `CREATE DATABASE gvmc;`)

3. **Local dry run** (optional but recommended):
   ```
   pip install -r requirements.txt
   cp .env.example .env   # fill in DB_URL etc., then export them
   python run_local.py
   python smoke_test.py   # routing/parsing checks, no DB needed
   curl http://localhost:8000/api/wards
   ```

4. **First deploy:**
   ```
   sam build
   sam deploy --guided --config-env staging
   ```
   Capture the printed `ApiUrl` output.

5. **Seed placeholder GeoJSON:**
   ```
   DB_URL=... S3_BUCKET=gvmc-sw14-data AWS_REGION=ap-south-1 python seed/seed_geojson.py
   ```

6. **Frontend cutover:** in the Amplify console, set `VITE_API_URL` = the `ApiUrl` output, unset/`false`
   `VITE_MOCK`, rebuild.

7. **End-to-end check:** click through every frontend view against the real API (map polygons, stats,
   verify action, chat, CSV upload, alert export).

8. **CI/CD:** `.github/workflows/deploy.yml` auto-deploys on push to `main`. Requires repo secrets:
   `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `S3_BUCKET`.

## Known tradeoffs (see plan for full rationale)

- RDS is publicly accessible rather than VPC-isolated — acceptable for a demo, not production.
- Chat/AI uses direct Bedrock `invoke_model` calls with hand-built context, not a full Bedrock Agent —
  simpler and more reliable for a one-shot deploy; both AI functions fall back to a templated response
  if Bedrock is unreachable, so the API never breaks because of AI.
- Seed data intentionally mirrors `frontend/src/mocks/data/*.js` 1:1 so the live API produces results
  consistent with what the frontend was built and demoed against.
