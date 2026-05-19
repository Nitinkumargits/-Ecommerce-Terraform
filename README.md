# Ecommerce — Infrastructure & Deployment

Terraform + GitHub Actions pipelines that stand up [https://ecommerce.nitinkdevs.com](https://ecommerce.nitinkdevs.com) on a single AWS EC2 host running both app containers (frontend + backend) via `docker compose`, fronted by system Nginx with a Let's Encrypt certificate.

App code lives in separate repos:

- Frontend: [Nitinkumargits/Ecommerce-FrontEnd](https://github.com/Nitinkumargits/Ecommerce-FrontEnd) → `nitinkdocker18/ecommerce:frontend`
- Backend: [Nitinkumargits/Ecommerce-backend](https://github.com/Nitinkumargits/Ecommerce-backend) → `nitinkdocker18/ecommerce:api`
- This repo: infra (Terraform) + deploy automation only.

---

## Architecture

```
                 Route 53 (nitinkdevs.com)
                          |
                  A: ecommerce.nitinkdevs.com -> EC2 EIP
                          |
                  +-------v--------+
                  |  EC2 (Ubuntu)  |   tag Name=ecommerce-server
                  |                |
                  |  systemd nginx |   :443 TLS (certbot)
                  |   |- /    -> 127.0.0.1:8080 (frontend)
                  |   |- /api -> 127.0.0.1:4000 (backend)
                  |                |
                  |  docker compose|
                  |   |- frontend  |   nitinkdocker18/ecommerce:frontend -> 127.0.0.1:8080:80
                  |   |- backend   |   nitinkdocker18/ecommerce:api      -> 127.0.0.1:4000:4000
                  |                |   env_file: /opt/ecommerce/backend.env
                  +----------------+
                          |
              MongoDB Atlas, Stripe, Cloudinary, Gmail SMTP (external)
```

---

## Repo layout

```
.
├── .github/workflows/
│   ├── terraform-apply.yml      # provisions VPC/EC2/EIP/SG/Route 53
│   ├── terraform-destroy.yml    # tears the above down + empties TF state bucket
│   └── deploy.yml               # rolls images on the EC2 host via docker compose
├── terraform/                   # IaC (S3-backed state)
├── compose/docker-compose.yml   # scp'd to /opt/ecommerce/ on the host
├── nginx/ecommerce.conf         # scp'd to /etc/nginx/sites-available/ecommerce
└── README.md
```

---

## Required GitHub secrets (this repo)

| Secret                  | Used by                          | Notes |
|-------------------------|----------------------------------|-------|
| `AWS_ACCESS_KEY_ID`     | apply, destroy, deploy           | IAM user with EC2, VPC, Route 53, S3, EC2 Instance Connect |
| `AWS_SECRET_ACCESS_KEY` | apply, destroy, deploy           | |
| `MY_IP`                 | apply, destroy                   | Your public IP, e.g. `203.0.113.42` (auto-suffixed `/32`) |
| `EC2_SSH_KEY`           | apply, destroy, deploy           | Private OpenSSH key. Pub key is derived from this. |
| `EC2_USER`              | deploy                           | `ubuntu` |
| `PROD_ENV_B64`          | deploy                           | Base64 of the backend `.env`. See template below. |

### `PROD_ENV_B64` template

Encode this file with `base64 -w0 backend.env` (Linux) or `[Convert]::ToBase64String([IO.File]::ReadAllBytes('backend.env'))` (PowerShell) and paste the result.

```env
PORT=4000
NODE_ENV=production
FRONTEND_URL=https://ecommerce.nitinkdevs.com

DB_URI=mongodb+srv://<user>:<password>@ecommerce-cluster.uon9w.mongodb.net/?appName=Ecommerce-cluster

JWT_SECRET=<long-random-string>
JWT_EXPIRES_IN=50d
JWT_COOKIE_EXPIRES_IN=50

SMPT_SERVICE=gmail
SMPT_HOST=smtp.gmail.com
SMPT_PORT=465
SMPT_MAIL=<gmail-address>
SMPT_PASSWORD=<gmail-app-password>

CLOUDINARY_CLOUD_NAME=<cloud-name>
CLOUDINARY_API_KEY=<api-key>
CLOUDINARY_API_SECRET=<api-secret>

STRIPE_SECRET_KEY=sk_test_...
STRIPE_API_KEY=pk_test_...
```

---

## First-time setup

1. **Create the GitHub secrets** above on this repo.
2. **Run `Terraform Apply`** (Actions tab → `Terraform Apply` → Run workflow). Wait for green; note the EC2 IP in the job summary.
3. **Verify DNS**: `dig +short ecommerce.nitinkdevs.com` should return the EC2 EIP within a few minutes.
4. **Run `Deploy`** (Actions tab → `Deploy` → Run workflow). Leave tags at default (`frontend` / `api`).
5. Hit [https://ecommerce.nitinkdevs.com](https://ecommerce.nitinkdevs.com). First load may take ~10s while certbot issues the cert.

---

## Continuous deployment

On every push to `master` in `Ecommerce-FrontEnd` or `Ecommerce-backend`:

1. The app repo's own workflow builds and pushes the Docker image to Docker Hub.
2. The app repo's final step fires a `repository_dispatch` to this repo (`frontend-image-pushed` or `api-image-pushed`).
3. This repo's `Deploy` workflow auto-runs, pulls the new image, and rolls the affected container.

To enable this, each app repo needs:

- a `DEPLOY_DISPATCH_PAT` secret (fine-grained PAT with `contents: write` on this repo), and
- the dispatch step appended to its own `dockerImage.yml` / `dockerimage.yml`.

See the patched workflows in those repos.

---

## Manual rollback

Tag your last known good images (e.g. `frontend-prev`, `api-prev`) and trigger `Deploy` with those tag inputs. `docker compose pull && up -d` will swap containers with zero state loss (env file is on the host).

---

## Tearing it down

`Terraform Destroy` workflow → type `destroy` in the confirm box. Removes:

- VPC, subnet, IGW, route table, security group
- EC2 instance + EIP + key pair
- Route 53 records for `ecommerce.nitinkdevs.com` and `www.ecommerce.nitinkdevs.com`
- S3 state bucket `nitinkdevs-ecommerce-tf-state`

Preserved (intentional):

- Root hosted zone `nitinkdevs.com`
- Docker Hub images
- MongoDB Atlas / Stripe / Cloudinary data

---

## Troubleshooting

| Symptom | Check |
|---|---|
| `Deploy` fails with "No running EC2 instance with tag Name=ecommerce-server" | Run `Terraform Apply` first. |
| 502 from Nginx on `/api/*` | `sudo docker compose -f /opt/ecommerce/docker-compose.yml logs backend --tail=200` |
| Certbot fails | DNS not propagated yet. Re-run `Deploy` after a few minutes; site continues on HTTP in the meantime. |
| SSH push fails | EC2 Instance Connect key is only valid 60s — re-run the workflow. |
| Backend can't reach Mongo | Confirm `DB_URI` and Atlas IP allow-list (set to `0.0.0.0/0` or whitelist the EIP). |
