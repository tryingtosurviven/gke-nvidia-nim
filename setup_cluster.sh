gcloud auth login

export PROJECT_ID=MLHGKE2026
export REGION=asia-southeast1
export ZONE=asia-southeast1-a
export CLUSTER_NAME=nim-demo
export NODE_POOL_MACHINE_TYPE=g2-standard-16
export CLUSTER_MACHINE_TYPE=e2-standard-4
export GPU_TYPE=nvidia-l4
export GPU_COUNT=1

#Create GKE Cluster:
gcloud container clusters create ${CLUSTER_NAME} \
    --project=${PROJECT_ID} \
    --location=${ZONE} \
    --release-channel=rapid \
    --machine-type=${CLUSTER_MACHINE_TYPE} \
    --num-nodes=1

#Create GPU node pool:
gcloud container node-pools create gpupool \
    --accelerator type=${GPU_TYPE},count=${GPU_COUNT},gpu-driver-version=latest \
    --project=${PROJECT_ID} \
    --location=${ZONE} \
    --cluster=${CLUSTER_NAME} \
    --machine-type=${NODE_POOL_MACHINE_TYPE} \
    --num-nodes=1
