# Portworx Integration

## Introduction

The existing documentation on the partner page for integrating with Portworx describes a 2-step process for integrating with Konvoy.  These steps use a custom helm chart to integrate Portworx at initial cluster deployment time.  

A custom configuration for the Portworx helm chart was used to configure Portworx to automatically create EBS volumes.

There is an existing standard Portworx helm chart that may be more applicable for other deployment scenarios.

This repo is for **Konvoy deployments on AWS** only.  

Main Purpose: 

- Deploy Portworx on a Konvoy Cluster for AWS
- Integrate Portworx at Konvoy Cluster deployment time without disabling and enabling stateful add-ons
- Portworx with a custom configuration to support provisioning EBS volumes on AWS dynamically

This demo will include the steps needed to set up a POC deployment to demonstrate this functionality.  The setup for this is **NOT RECOMMENDED** for a production deployment - only to show the art of the possible.  

### Environment details

This testing was done with konvoy_v1.4.0-beta.1


### Getting Started

## Initialize the Konvoy configuration files:

```
konvoy init
```

## Configure Konvoy with custom storage provisioner

Edit the cluster.yaml

Disable the EBS Provisioner:

```
    - name: awsebscsiprovisioner
      enabled: false
    - name: awsebsprovisioner
      enabled: false
      values: |
        storageclass:
          isDefault: false
```

Enable the custom add-on repo and Portworx add-on

```
  - configRepository: https://github.com/mesosphere/konvoy-training/integrations/portworx
    configVersion: stable-0.1
    addonsList:
    - name: pwxprovisioner
      enabled: true
```

### Deploy Konvoy

Deploy Konvoy with the custom add-on with Portworx

```
konvoy up --yes
```

Validate the storage class was created after the deployment:

```
kubectl get sc

NAME                    PROVISIONER                     AGE
portworx-sc (default)   kubernetes.io/portworx-volume   2d10h
stork-snapshot-sc       stork-snapshot                  2d10h
```

Check default services deployed:

```
kubectl get pvc -A

NAMESPACE    NAME                                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
kubeaddons   data-elasticsearch-kubeaddons-data-0                    Bound    pvc-300e412b-6b66-4b9d-997d-5ab76b656a70   30Gi       RWO            portworx-sc    2d11h
kubeaddons   data-elasticsearch-kubeaddons-data-1                    Bound    pvc-633cb50e-ef44-432d-b504-9b9f50fa9540   30Gi       RWO            portworx-sc    2d10h
kubeaddons   data-elasticsearch-kubeaddons-master-0                  Bound    pvc-ca5758f7-b40b-4079-b70b-9b9dcf157a6f   4Gi        RWO            portworx-sc    2d11h
kubeaddons   data-elasticsearch-kubeaddons-master-1                  Bound    pvc-8f9df285-e7b5-49eb-bddb-f3ac45ca7709   4Gi        RWO            portworx-sc    2d10h
kubeaddons   data-elasticsearch-kubeaddons-master-2                  Bound    pvc-2d017cc2-7d05-4270-b1b0-2f9cf07f8cb3   4Gi        RWO            portworx-sc    2d10h
kubeaddons   db-prometheus-prometheus-kubeaddons-prom-prometheus-0   Bound    pvc-fe670c18-d9b5-4ec5-9611-897bb308d793   50Gi       RWO            portworx-sc    2d10h
velero       data-minio-0                                            Bound    pvc-2cb7a398-4fe3-4a18-be10-dba0f4e7b50a   10Gi       RWO            portworx-sc    2d10h
velero       data-minio-1                                            Bound    pvc-50124b80-76d1-4c05-80b4-e2fff7e2fe85   10Gi       RWO            portworx-sc    2d10h
velero       data-minio-2                                            Bound    pvc-69b43c7f-eba9-4718-aa5f-511d501266f7   10Gi       RWO            portworx-sc    2d10h
velero       data-minio-3                                            Bound    pvc-9a22f8bd-b1ab-4bfa-8dda-acbd05df9fb5   10Gi       RWO            portworx-sc    2d10h
```
