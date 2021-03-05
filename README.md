# jupyterhub-workload-identity-gke
Script to setup Jupyterhub using workload identity credentials

The script creates a Kubernetes Cluster, runs the Jupyterhub helm chart (0.10.6) and uses Workload Identity to connect to GCP resources.

The Dockerfile for the Jupyterlab single user with gcloud can be [obtained here](https://github.com/snamburi3/gcloud-jupyterhub).