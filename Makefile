.PHONY: dev stop build migrate migrate-staging migrate-prod \
        logs-staging logs-prod status-staging status-prod status

GCP_PROJECT ?= todo-gcp-498308
GCP_REGION  ?= us-central1

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
	@echo "==> Applying migrations to staging via docker exec..."
	@for f in $$(ls supabase/migrations/*.sql | sort); do \
	  echo "  Applying $$f"; \
	  gcloud compute scp "$$f" supabase-staging:~/mig.sql \
	    --project=$(GCP_PROJECT) --zone=$(GCP_REGION)-a --quiet; \
	  gcloud compute ssh supabase-staging \
	    --project=$(GCP_PROJECT) --zone=$(GCP_REGION)-a \
	    --command="sudo docker exec -i supabase-db psql -U postgres postgres < ~/mig.sql; rm -f ~/mig.sql" || true; \
	done
	@echo "==> Staging migration done."

migrate-prod:
	@echo "==> Applying migrations to prod via docker exec..."
	@for f in $$(ls supabase/migrations/*.sql | sort); do \
	  echo "  Applying $$f"; \
	  gcloud compute scp "$$f" supabase-prod:~/mig.sql \
	    --project=$(GCP_PROJECT) --zone=$(GCP_REGION)-a --quiet; \
	  gcloud compute ssh supabase-prod \
	    --project=$(GCP_PROJECT) --zone=$(GCP_REGION)-a \
	    --command="sudo docker exec -i supabase-db psql -U postgres postgres < ~/mig.sql; rm -f ~/mig.sql" || true; \
	done
	@echo "==> Prod migration done."

logs-staging:
	gcloud run services logs read frontend-staging --project $(GCP_PROJECT) --region $(GCP_REGION) --limit 50
	gcloud run services logs read backend-staging --project $(GCP_PROJECT) --region $(GCP_REGION) --limit 50

logs-prod:
	gcloud run services logs read frontend-prod --project $(GCP_PROJECT) --region $(GCP_REGION) --limit 50
	gcloud run services logs read backend-prod --project $(GCP_PROJECT) --region $(GCP_REGION) --limit 50

status-staging:
	@echo "=== Staging URLs ==="
	@gcloud run services describe frontend-staging --project $(GCP_PROJECT) --region $(GCP_REGION) --format "value(status.url)" 2>/dev/null || echo "Not deployed"
	@gcloud run services describe backend-staging --project $(GCP_PROJECT) --region $(GCP_REGION) --format "value(status.url)" 2>/dev/null || echo "Not deployed"

status-prod:
	@echo "=== Production URLs ==="
	@gcloud run services describe frontend-prod --project $(GCP_PROJECT) --region $(GCP_REGION) --format "value(status.url)" 2>/dev/null || echo "Not deployed"
	@gcloud run services describe backend-prod --project $(GCP_PROJECT) --region $(GCP_REGION) --format "value(status.url)" 2>/dev/null || echo "Not deployed"

status: status-staging status-prod

# ─────────────────────────────────────────────
# GCP setup (run once to provision infrastructure)
# ─────────────────────────────────────────────
.PHONY: setup-gcp gcp-enable-apis gcp-service-accounts gcp-artifact-registry \
        gcp-vms gcp-firewall studio-staging studio-prod

setup-gcp: gcp-enable-apis gcp-service-accounts gcp-artifact-registry gcp-vms gcp-firewall
	@echo "==> GCP infrastructure provisioned."
	@echo "==> Next steps:"
	@echo "    1. make gcp-vms  (already done by setup-gcp)"
	@echo "    2. Run infra/generate-supabase-keys.py and infra/setup-supabase-vm.sh on each VM"
	@echo "    3. Populate Secret Manager with credentials"

gcp-enable-apis:
	gcloud services enable \
	  run.googleapis.com \
	  sqladmin.googleapis.com \
	  compute.googleapis.com \
	  artifactregistry.googleapis.com \
	  secretmanager.googleapis.com \
	  cloudbuild.googleapis.com \
	  cloudresourcemanager.googleapis.com \
	  iam.googleapis.com \
	  iap.googleapis.com \
	  --project $(GCP_PROJECT)

gcp-service-accounts:
	gcloud iam service-accounts create cloud-build-sa \
	  --display-name="Cloud Build Service Account" \
	  --project $(GCP_PROJECT) 2>/dev/null || true
	gcloud iam service-accounts create cloud-run-sa \
	  --display-name="Cloud Run Service Account" \
	  --project $(GCP_PROJECT) 2>/dev/null || true
	gcloud iam service-accounts create supabase-vm-sa \
	  --display-name="Supabase VM Service Account" \
	  --project $(GCP_PROJECT) 2>/dev/null || true
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
	  --member="serviceAccount:cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com" \
	  --role="roles/run.admin"
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
	  --member="serviceAccount:cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com" \
	  --role="roles/artifactregistry.writer"
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
	  --member="serviceAccount:cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com" \
	  --role="roles/secretmanager.secretAccessor"
	gcloud iam service-accounts add-iam-policy-binding \
	  cloud-run-sa@$(GCP_PROJECT).iam.gserviceaccount.com \
	  --member="serviceAccount:cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com" \
	  --role="roles/iam.serviceAccountUser" \
	  --project $(GCP_PROJECT)
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
	  --member="serviceAccount:cloud-run-sa@$(GCP_PROJECT).iam.gserviceaccount.com" \
	  --role="roles/secretmanager.secretAccessor"
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
	  --member="serviceAccount:cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com" \
	  --role="roles/cloudbuild.builds.builder"
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
	  --member="serviceAccount:cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com" \
	  --role="roles/logging.logWriter"

gcp-artifact-registry:
	gcloud artifacts repositories create todo-app \
	  --repository-format=docker \
	  --location=$(GCP_REGION) \
	  --description="Docker images for todo-gcp" \
	  --project $(GCP_PROJECT) 2>/dev/null || true
	gcloud auth configure-docker $(GCP_REGION)-docker.pkg.dev

gcp-vms:
	gcloud compute instances create supabase-staging \
	  --project=$(GCP_PROJECT) \
	  --zone=$(GCP_REGION)-a \
	  --machine-type=e2-standard-2 \
	  --image-family=ubuntu-2204-lts \
	  --image-project=ubuntu-os-cloud \
	  --boot-disk-size=50GB \
	  --boot-disk-type=pd-ssd \
	  --service-account=supabase-vm-sa@$(GCP_PROJECT).iam.gserviceaccount.com \
	  --scopes=cloud-platform \
	  --tags=supabase-vm \
	  --metadata=enable-oslogin=true 2>/dev/null || true
	gcloud compute instances create supabase-prod \
	  --project=$(GCP_PROJECT) \
	  --zone=$(GCP_REGION)-a \
	  --machine-type=e2-standard-2 \
	  --image-family=ubuntu-2204-lts \
	  --image-project=ubuntu-os-cloud \
	  --boot-disk-size=50GB \
	  --boot-disk-type=pd-ssd \
	  --service-account=supabase-vm-sa@$(GCP_PROJECT).iam.gserviceaccount.com \
	  --scopes=cloud-platform \
	  --tags=supabase-vm \
	  --metadata=enable-oslogin=true 2>/dev/null || true

gcp-firewall:
	gcloud compute firewall-rules create allow-supabase-api \
	  --project=$(GCP_PROJECT) \
	  --direction=INGRESS \
	  --priority=1000 \
	  --network=default \
	  --action=ALLOW \
	  --rules=tcp:8000 \
	  --target-tags=supabase-vm \
	  --source-ranges=0.0.0.0/0 \
	  --description="Allow Supabase Kong API" 2>/dev/null || true

# SSH tunnels for Studio access — run in a separate terminal, then open localhost:54323 or 54324
studio-staging:
	gcloud compute ssh supabase-staging \
	  --project=$(GCP_PROJECT) \
	  --zone=$(GCP_REGION)-a \
	  -- -L 54323:localhost:3000 -N

studio-prod:
	gcloud compute ssh supabase-prod \
	  --project=$(GCP_PROJECT) \
	  --zone=$(GCP_REGION)-a \
	  -- -L 54324:localhost:3000 -N
