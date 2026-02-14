export PATH=$PATH:/home/codespace/google-cloud-sdk/bin

gcloud auth login

# 1. Set your Project & Hardware Variables
export PROJECT_ID=MLHGKE2026
export REGION=asia-southeast1
export ZONE=asia-southeast1-a
export CLUSTER_NAME=nim-demo
export NODE_POOL_MACHINE_TYPE=g2-standard-16
export CLUSTER_MACHINE_TYPE=e2-standard-4
export GPU_TYPE=nvidia-l4
export GPU_COUNT=1

# Add NGC to Path
export PATH=$PATH:$(pwd)/ngc-cli

# 2. Grab the Secret from GitHub
export NGC_CLI_API_KEY="${NVIDIA_GKE_NIM_MLH2026_API_KEY}"

# 3. Securely Login to NVIDIA
ngc config set --api-key $NGC_CLI_API_KEY
echo "$NGC_CLI_API_KEY" | docker login nvcr.io --username '$oauthtoken' --password-stdin

# 4. Create GKE Cluster (This takes 5-10 minutes)
gcloud container clusters create ${CLUSTER_NAME} \
    --project=${PROJECT_ID} \
    --location=${ZONE} \
    --release-channel=rapid \
    --machine-type=${CLUSTER_MACHINE_TYPE} \
    --num-nodes=1

# 5. Create GPU node pool
gcloud container node-pools create gpupool \
    --accelerator type=${GPU_TYPE},count=${GPU_COUNT},gpu-driver-version=latest \
    --project=${PROJECT_ID} \
    --location=${ZONE} \
    --cluster=${CLUSTER_NAME} \
    --machine-type=${NODE_POOL_MACHINE_TYPE} \
    --num-nodes=1
#Deploy and test NVIDIA NIM
helm fetch https://helm.ngc.nvidia.com/nim/charts/nim-llm-1.3.0.tgz --username='$oauthtoken' --password=$NGC_CLI_API_KEY

#Create a NIM Namespace:
kubectl create namespace nim

#Configure secrets:
kubectl create secret docker-registry registry-secret --docker-server=nvcr.io --docker-username='$oauthtoken'     --docker-password=$NGC_CLI_API_KEY -n nim
kubectl create secret generic ngc-api --from-literal=NGC_API_KEY=$NGC_CLI_API_KEY -n nim

#Setup NIM Configuration:
cat <<EOF > nim_custom_value.yaml
image:
  repository: "nvcr.io/nim/meta/llama3-8b-instruct" # container location
  tag: 1.0.0 # NIM version you want to deploy
model:
  ngcAPISecret: ngc-api  # name of a secret in the cluster that includes a key named NGC_CLI_API_KEY and is an NGC API key
persistence:
  enabled: true
imagePullSecrets:
  -   name: registry-secret # name of a secret used to pull nvcr.io images, see https://kubernetes.io/docs/tasks/    configure-pod-container/pull-image-private-registry/
EOF

#Launching NIM deployment:
helm install my-nim nim-llm-1.3.0.tgz -f nim_custom_value.yaml --namespace nim

#Verify NIM pod is running:
kubectl get pods -n nim

#Testing NIM deployment:
kubectl port-forward service/my-nim-nim-llm 8000:8000 -n nim

curl -X 'POST' \
  'http://localhost:8000/v1/chat/completions' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "messages": [
    {
      "content": "You are a polite and respectful chatbot helping people plan a vacation.",
      "role": "system"
    },
    {
      "content": "What should I do for a 4 day vacation in Spain?",
      "role": "user"
    }
  ],
  "model": "meta/llama3-8b-instruct",
  "max_tokens": 128,
  "top_p": 1,
  "n": 1,
  "stream": false,
  "stop": "\n",
  "frequency_penalty": 0.0
}'
