#!/bin/bash

## Export variables
PROJECT_ID="" # <----- replace with your project ID
CLUSTER_ID="cluster-1"
ZONE="us-east1-b"
KUBE_NAMESPACE="kube-identity"
HELM_RELEASE="jhub"
GCP_SVC="identity-workload-sa"
KUBE_SVC="workload-identity-k8s-sa"

## Create a Kubernetes Cluster
gcloud beta container --project ${PROJECT_ID} clusters create ${CLUSTER_ID} \
--zone ${ZONE} --no-enable-basic-auth  --machine-type "e2-medium" \
--image-type "COS" --disk-type "pd-standard" --disk-size "100" \
--metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/cloud-platform" \
--num-nodes "4" --enable-stackdriver-kubernetes --enable-ip-alias \
--network "projects/${PROJECT_ID}/global/networks/default" \
--subnetwork "projects/${PROJECT_ID}/regions/us-east1/subnetworks/default" \
--default-max-pods-per-node "110" --no-enable-master-authorized-networks \
--addons HorizontalPodAutoscaling,HttpLoadBalancing --enable-autoupgrade \
--enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 \
--workload-pool "${PROJECT_ID}.svc.id.goog"

## connect to cluster
gcloud container clusters get-credentials ${CLUSTER_ID} --zone=${ZONE} --project ${PROJECT_ID}

## create gcp service account (GSA)
gcloud iam service-accounts create ${GCP_SVC} --project ${PROJECT_ID} \
--description="Service account for Workload Identity" \
--display-name="${PROJECT_ID} - GCP Workload Identity Service account"

## create k8s namespace
kubectl create namespace ${KUBE_NAMESPACE}

## create a service account for our k8s namespace
kubectl create serviceaccount ${KUBE_SVC} --namespace=${KUBE_NAMESPACE}

## bind GCP SA(GSA) with k8s SA (KSA)
gcloud iam service-accounts add-iam-policy-binding --role=roles/iam.workloadIdentityUser --member=serviceAccount:${PROJECT_ID}.svc.id.goog[${KUBE_NAMESPACE}/${KUBE_SVC}] identity-workload-sa@${PROJECT_ID}.iam.gserviceaccount.com

## Annotate the kubernetes service account (KSA)
kubectl annotate serviceaccount --namespace ${KUBE_NAMESPACE} ${KUBE_SVC} iam.gke.io/gcp-service-account=${GCP_SVC}@${PROJECT_ID}.iam.gserviceaccount.com

## Install jupyterhub 0.10.6
helm upgrade --cleanup-on-fail   --install ${HELM_RELEASE} jupyterhub/jupyterhub   --namespace ${KUBE_NAMESPACE} --version=0.10.6 --values config.yaml --set serviceAccount.annotations.'iam\.gke\.io/gcp-service-account'='${GCP_SVC}@${PROJECT_ID}.iam.gserviceaccount.com'

## get pods in a namespace
kubectl --namespace=${KUBE_NAMESPACE} get pod

## You can find the public IP (if exists)
kubectl --namespace=${KUBE_NAMESPACE} get svc proxy-public

## get namespaces
kubectl get deployments -o wide --namespace ${KUBE_NAMESPACE}

## get_pods
kubectl get pods -n ${KUBE_NAMESPACE}

## get_versions: ## lists the container images used for particular pods
kubectl get pods -l release=${HELM_RELEASE} -n ${KUBE_NAMESPACE} -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{range .spec.containers[*]}{.name}{'\t'}{.image}{'\n\n'}{end}{'\n'}{end}{'\n'}"

## get_status:
kubectl get pod,svc,deployments,pv,pvc,ingress -n ${KUBE_NAMESPACE}

## delete release
#helm delete ${HELM_RELEASE}

## delete cluster
#gcloud container clusters delete ${CLUSTER_ID} --project ${PROJECT_ID} --zone=${ZONE} 

