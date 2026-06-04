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
        gcp-vms gcp-firewall studio-staging studio-prod \
        gcp-connect-github gcp-build-triggers

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

# ─────────────────────────────────────────────
# CI/CD: GitHub connection and Cloud Build triggers
# Run gcp-connect-github first (requires OAuth), then gcp-build-triggers
# ─────────────────────────────────────────────

gcp-connect-github:
	@echo "==> Granting Cloud Build P4SA Secret Manager permissions..."
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
	  --member="serviceAccount:service-$$(gcloud projects describe $(GCP_PROJECT) --format='value(projectNumber)')@gcp-sa-cloudbuild.iam.gserviceaccount.com" \
	  --role="roles/secretmanager.admin" --quiet
	@echo "==> Creating Cloud Build GitHub connection..."
	@echo "    You will be prompted to authorize GitHub access in your browser."
	gcloud builds connections create github github-connection \
	  --region=$(GCP_REGION) \
	  --project=$(GCP_PROJECT)
	@echo "==> Registering frontend repo..."
	gcloud builds repositories create todo-gcp-frontend \
	  --connection=github-connection \
	  --remote-uri=https://github.com/ksmelnad/todo-gcp-frontend.git \
	  --region=$(GCP_REGION) \
	  --project=$(GCP_PROJECT) 2>/dev/null || true
	@echo "==> Registering backend repo..."
	gcloud builds repositories create todo-gcp-backend \
	  --connection=github-connection \
	  --remote-uri=https://github.com/ksmelnad/todo-gcp-backend.git \
	  --region=$(GCP_REGION) \
	  --project=$(GCP_PROJECT) 2>/dev/null || true
	@echo "==> GitHub connection complete."

gcp-build-triggers:
	@echo "==> Creating Cloud Build triggers..."
	gcloud builds triggers create github \
	  --name=frontend-dev-to-staging \
	  --region=$(GCP_REGION) \
	  --repository=projects/$(GCP_PROJECT)/locations/$(GCP_REGION)/connections/github-connection/repositories/todo-gcp-frontend \
	  --branch-pattern='^dev$$' \
	  --build-config=cloudbuild.yaml \
	  --substitutions=_SERVICE_NAME=frontend-staging,_FRONTEND_URL=https://frontend-staging-sitwaunxna-uc.a.run.app,_SUPABASE_URL_SECRET=SUPABASE_URL_STAGING,_SUPABASE_ANON_KEY_SECRET=SUPABASE_ANON_KEY_STAGING,_SUPABASE_SVC_KEY_SECRET=SUPABASE_SERVICE_ROLE_KEY_STAGING \
	  --service-account=projects/$(GCP_PROJECT)/serviceAccounts/cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com \
	  --project=$(GCP_PROJECT) 2>/dev/null || true
	gcloud builds triggers create github \
	  --name=frontend-main-to-prod \
	  --region=$(GCP_REGION) \
	  --repository=projects/$(GCP_PROJECT)/locations/$(GCP_REGION)/connections/github-connection/repositories/todo-gcp-frontend \
	  --branch-pattern='^main$$' \
	  --build-config=cloudbuild.yaml \
	  --substitutions=_SERVICE_NAME=frontend-prod,_FRONTEND_URL=https://frontend-prod-sitwaunxna-uc.a.run.app,_SUPABASE_URL_SECRET=SUPABASE_URL_PROD,_SUPABASE_ANON_KEY_SECRET=SUPABASE_ANON_KEY_PROD,_SUPABASE_SVC_KEY_SECRET=SUPABASE_SERVICE_ROLE_KEY_PROD \
	  --service-account=projects/$(GCP_PROJECT)/serviceAccounts/cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com \
	  --project=$(GCP_PROJECT) 2>/dev/null || true
	gcloud builds triggers create github \
	  --name=backend-dev-to-staging \
	  --region=$(GCP_REGION) \
	  --repository=projects/$(GCP_PROJECT)/locations/$(GCP_REGION)/connections/github-connection/repositories/todo-gcp-backend \
	  --branch-pattern='^dev$$' \
	  --build-config=cloudbuild.yaml \
	  --substitutions=_SERVICE_NAME=backend-staging,_SUPABASE_URL_SECRET=SUPABASE_URL_STAGING,_SUPABASE_ANON_KEY_SECRET=SUPABASE_ANON_KEY_STAGING,_SUPABASE_SVC_KEY_SECRET=SUPABASE_SERVICE_ROLE_KEY_STAGING,_SUPABASE_JWT_SECRET=SUPABASE_JWT_SECRET_STAGING,_DATABASE_URL_SECRET=DATABASE_URL_STAGING \
	  --service-account=projects/$(GCP_PROJECT)/serviceAccounts/cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com \
	  --project=$(GCP_PROJECT) 2>/dev/null || true
	gcloud builds triggers create github \
	  --name=backend-main-to-prod \
	  --region=$(GCP_REGION) \
	  --repository=projects/$(GCP_PROJECT)/locations/$(GCP_REGION)/connections/github-connection/repositories/todo-gcp-backend \
	  --branch-pattern='^main$$' \
	  --build-config=cloudbuild.yaml \
	  --substitutions=_SERVICE_NAME=backend-prod,_SUPABASE_URL_SECRET=SUPABASE_URL_PROD,_SUPABASE_ANON_KEY_SECRET=SUPABASE_ANON_KEY_PROD,_SUPABASE_SVC_KEY_SECRET=SUPABASE_SERVICE_ROLE_KEY_PROD,_SUPABASE_JWT_SECRET=SUPABASE_JWT_SECRET_PROD,_DATABASE_URL_SECRET=DATABASE_URL_PROD \
	  --service-account=projects/$(GCP_PROJECT)/serviceAccounts/cloud-build-sa@$(GCP_PROJECT).iam.gserviceaccount.com \
	  --project=$(GCP_PROJECT) 2>/dev/null || true
	@echo "==> 4 Cloud Build triggers created."
	@echo "    View: https://console.cloud.google.com/cloud-build/triggers?project=$(GCP_PROJECT)"
