.PHONY: dev stop build migrate migrate-staging migrate-prod \
        logs-staging logs-prod status-staging status-prod status

# Load env vars from .env.local
ifneq (,$(wildcard .env.local))
  include .env.local
  export
endif

dev:
	pnpm supabase start
	docker compose up --build

stop:
	docker compose down
	pnpm supabase stop

build:
	docker compose build

migrate:
	pnpm supabase migration up

migrate-staging:
	pnpm supabase db push --db-url "$(DATABASE_URL_STAGING)"

migrate-prod:
	pnpm supabase db push --db-url "$(DATABASE_URL_PROD)"

logs-staging:
	gcloud run services logs read frontend-staging --project todo-gcp-498308 --region us-central1 --limit 50
	gcloud run services logs read backend-staging --project todo-gcp-498308 --region us-central1 --limit 50

logs-prod:
	gcloud run services logs read frontend-prod --project todo-gcp-498308 --region us-central1 --limit 50
	gcloud run services logs read backend-prod --project todo-gcp-498308 --region us-central1 --limit 50

status-staging:
	@echo "=== Staging URLs ==="
	@gcloud run services describe frontend-staging --project todo-gcp-498308 --region us-central1 --format "value(status.url)" 2>/dev/null || echo "Not deployed"
	@gcloud run services describe backend-staging --project todo-gcp-498308 --region us-central1 --format "value(status.url)" 2>/dev/null || echo "Not deployed"

status-prod:
	@echo "=== Production URLs ==="
	@gcloud run services describe frontend-prod --project todo-gcp-498308 --region us-central1 --format "value(status.url)" 2>/dev/null || echo "Not deployed"
	@gcloud run services describe backend-prod --project todo-gcp-498308 --region us-central1 --format "value(status.url)" 2>/dev/null || echo "Not deployed"

status: status-staging status-prod
