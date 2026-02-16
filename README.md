# AWS DevOps Assignment – Python App with CI/CD, Secrets Manager, CloudFormation, Manual Approvals & SNS

A Python Flask app (port **8000**) that retrieves a secret from **AWS Secrets Manager** (masked in the UI), with full CI/CD using **CodeCommit**, **CodeBuild**, **CodeDeploy**, and **CodePipeline**, including **manual approval** and **SNS** notifications. Infrastructure is defined in **CloudFormation** (infra + CI/CD stacks).

---

## Deliverables Summary

| Deliverable | Location |
|-------------|----------|
| **CloudFormation – Infrastructure** | `infra-ec2.yaml` |
| **CloudFormation – CI/CD** | `cicd.yaml` |
| **Application** | `app.py`, `requirements.txt`, `templates/index.html` |
| **Build** | `buildspec.yml` |
| **Deploy** | `appspec.yml`, `scripts/` (lifecycle hooks) |

---

## Application Requirements

- **Flask** app on **port 8000**.
- Reads a secret from **AWS Secrets Manager** at runtime.
- Secret is **masked** (only last 4 characters shown) before returning to the client.
- Displays a **greeting** on the home page.

### Run locally

```bash
python -m venv .venv
.venv\Scripts\activate   # Windows
# source .venv/bin/activate   # Linux/macOS

pip install -r requirements.txt
set APP_SECRET_NAME=devops-demo/app-secret   # optional; matches infra default
python app.py
```

Open **http://localhost:8000**

### How the secret name is passed to the app

1. **Infra stack** creates the secret and, in EC2 UserData (cfn-init), writes the secret name to **`/etc/devops-demo/secret-name`** on the instance.
2. **CodeDeploy** runs `scripts/application_start.sh`, which reads that file and sets **`APP_SECRET_NAME`** for the process.
3. **App** (`app.py`) uses **`os.environ.get("APP_SECRET_NAME", "devops-demo/app-secret")`**, so it gets the name from the environment (or falls back to the default if the file is missing).

So the secret name flows: **CloudFormation (AppSecret)** → **cfn-init file** → **application_start.sh** → **APP_SECRET_NAME** → **app.py**.

### Endpoints

| Path        | Description                          |
|------------|--------------------------------------|
| `/`        | Home (greeting + masked secret)       |
| `/health`  | Health check (JSON)                  |
| `/api/info`| App info + secret retrieved (masked) |

---

## AWS Deployment (CloudFormation)

**Region:** `us-east-1` (set `AWS_DEFAULT_REGION=us-east-1` or use `--region us-east-1`).  
**EC2 access:** Session Manager (no SSH key required); the infra stack attaches `AmazonSSMManagedInstanceCore` to the EC2 role.

### 1. Deploy infrastructure stack first

Creates: **AWS Secrets Manager** secret (app password), EC2, IAM role (Secrets Manager + CodeDeploy + Session Manager), instance profile, Security Group, and UserData that installs the **CodeDeploy agent** and creates `/var/www/devops-demo` with a **virtual environment**. The secret is created and managed in this stack; the app reads it at runtime and masks it in the UI.

**us-east-1, no key pair (Session Manager only):**

```bash
aws cloudformation create-stack --region us-east-1 \
  --stack-name devops-infra \
  --template-body file://infra-ec2.yaml \
  --parameters \
    ParameterKey=KeyName,ParameterValue= \
    ParameterKey=SecretValue,ParameterValue=YourSecretPassword \
  --capabilities CAPABILITY_NAMED_IAM
```

- **KeyName**: Leave empty for Session Manager only (no SSH key).
- **SecretValue**: Value stored in Secrets Manager (app reads and masks it).
- Wait until stack status is `CREATE_COMPLETE`:
  ```bash
  aws cloudformation wait stack-create-complete --stack-name devops-infra --region us-east-1
  ```

### 2. Deploy CI/CD stack

Creates: **CodeCommit** repo, **CodeBuild** project, **CodeDeploy** application & deployment group, **CodePipeline** (Source → Build → **Manual Approval** → Deploy), **SNS** topics (approval, pipeline events, CodeDeploy events), and **EventBridge** rule for pipeline state changes → SNS.

```bash
aws cloudformation create-stack --region us-east-1 \
  --stack-name devops-cicd \
  --template-body file://cicd.yaml \
  --parameters ParameterKey=EmailForNotifications,ParameterValue=your@email.com ParameterKey=CodeCommitRepoName,ParameterValue=devops-demo-app \
  --capabilities CAPABILITY_NAMED_IAM
```

- **EmailForNotifications**: Confirm the three SNS email subscriptions (approval, pipeline, deployment) from your inbox.
- **CodeCommitRepoName**: Name of the CodeCommit repository (default: `devops-demo-app`). If you use a different name here or changed it manually in the console, use that same name when pushing code and in any clone URLs.
- Wait: `aws cloudformation wait stack-create-complete --stack-name devops-cicd --region us-east-1`

### 3. Push application code to CodeCommit

Get the clone URL from the **cicd** stack output `CodeCommitRepoCloneUrlHttp`, or use the repo name you set (e.g. if you passed `CodeCommitRepoName` or renamed the repo manually, use that name in the URL):

```bash
# Replace REPO_NAME with your repo name (e.g. devops-demo-app or the name you set)
git clone https://git-codecommit.us-east-1.amazonaws.com/v1/repos/REPO_NAME repo-cc
cd repo-cc
# Copy app files into repo-cc: app.py, requirements.txt, buildspec.yml, appspec.yml, templates/, scripts/
git add .
git commit -m "Initial app for CodeDeploy"
git branch -M main
git push -u origin main
```

If you **manually renamed the repo** in the AWS Console, the pipeline source may still point to the old name. Either: (1) **Edit the pipeline** in CodePipeline → Edit → Source stage → choose the renamed repository and **main** branch and save, or (2) **Update the stack** with the new repo name (only if the stack’s repo resource is still the one you renamed; otherwise keep the pipeline in sync by editing the Source action to the correct repo).

If the repo was created empty, ensure the default branch is **main** and the first push creates it. The pipeline is configured to use **main** and **PollForSourceChanges: true**.

### 4. Run the pipeline

1. **Source** stage pulls from CodeCommit.
2. **Build** stage runs CodeBuild (`buildspec.yml`) and produces `deploy.zip` for CodeDeploy.
3. **Approval** stage waits for manual approval; an **email** is sent via SNS (approve/reject in CodePipeline or from the link in the email).
4. **Deploy** stage runs CodeDeploy (EC2 in-place) using `appspec.yml` and scripts in `scripts/`.

After approval and a successful deploy, the app runs on the EC2 instance at **http://&lt;EC2-public-IP&gt;:8000**.

### Connect to EC2 via Session Manager (no SSH key)

1. Get the instance ID from the infra stack output or:  
   `aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Name,Values=devops-demo" --query "Reservations[0].Instances[0].InstanceId" --output text`
2. Start a session:  
   `aws ssm start-session --region us-east-1 --target <instance-id>`
3. Or use **EC2 → Instances → Select instance → Connect → Session Manager** in the AWS Console.

---

## Project layout (for CodeCommit / repo)

```
aws-devops-demo/
├── app.py                 # Flask app (port 8000, Secrets Manager, masked secret)
├── requirements.txt      # flask, boto3
├── buildspec.yml          # CodeBuild → deploy.zip for CodeDeploy
├── appspec.yml            # CodeDeploy EC2 in-place + lifecycle hooks
├── templates/
│   └── index.html        # Greeting + masked secret
├── scripts/               # CodeDeploy lifecycle hooks
│   ├── application_stop.sh
│   ├── before_install.sh
│   ├── after_install.sh
│   ├── application_start.sh
│   └── validate_service.sh
├── infra-ec2.yaml         # CloudFormation – EC2, IAM, Secret, SG
├── cicd.yaml              # CloudFormation – CodeCommit, CodeBuild, CodeDeploy, Pipeline, SNS
├── Dockerfile             # Optional local/container run
└── README.md
```

---

## Screenshots (for assignment submission)

Capture:

1. **CloudFormation**: Stacks **devops-infra** and **devops-cicd** in **CREATE_COMPLETE** (or **UPDATE_COMPLETE**).
2. **CodePipeline**: Execution history showing **Source** → **Build** → **Approval** → **Deploy** (all green).
3. **Manual approval**: Email received for approval and/or the approval step in the pipeline.
4. **SNS**: Pipeline state change and/or CodeDeploy deployment notifications (e.g. email or SNS topic).
5. **EC2**: Browser or `curl` to **http://&lt;EC2-public-IP&gt;:8000** showing the greeting and that the app is running.

---

## Optional: Run with Docker (port 8000)

```bash
docker build -t aws-devops-demo .
docker run -p 8000:8000 -e APP_SECRET_NAME=devops-demo/app-secret -e AWS_ACCESS_KEY_ID=... -e AWS_SECRET_ACCESS_KEY=... -e AWS_DEFAULT_REGION=... aws-devops-demo
```

Note: Update `Dockerfile` to use `EXPOSE 8000` and `CMD` on port 8000 if you use this for the same app.

---

## License

MIT
"# aws-devops-assignment" 
