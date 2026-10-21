# MinIO AIStor Helm Charts

Hyperscale Object Store for AI

MinIO AIStor is designed to allow enterprises to consolidate all of
their data on a single, private cloud namespace. Architected using
the same principles as the hyperscalers, AIStor delivers performance
at scale at a fraction of the cost compared to the public cloud.

AIStor runs in Kubernetes.

## Pre-requisites

- An active Kubernetes environment running a [maintained version](https://kubernetes.io/releases/)
- [`kubectl` CLI tool](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [`helm` CLI tool](https://helm.sh/docs/intro/install/)

### Environment

You can run MinIO AIStor Helm charts on Kubernetes providers such as

- Redhat Openshift
- Upstream Kubernetes
- Google Kubernetes Engine
- Amazon Elastic Kubernetes Service
- Azure Kubernetes Service

Other Kubernetes providers may also work.

## MinIO AIStor Helm Repository

```shell
helm repo add minio https://helm.min.io/
helm repo update
```

When you add the repo, you can see the available charts with the following command:

```shell
helm search repo minio
```

### Deprecated charts

MinIO no longer updates the following charts. Use the replacement chart for new installations.

| Deprecated chart              | Replacement chart  |
|-------------------------------|--------------------|
| `aistor-objectstore-operator` | `aistor-operator`  |
| `aistor-keymanager-operator`  | `minkms-operator`  |
| `aistor-keymanager`           | `minkms`           |
| `aistor-volumemanager`        | `directpv`         |

All published versions of the deprecated charts stay in this repository, so existing installations keep working.

## AIStor DirectPV

DirectPV is a CSI driver for Direct Attached Storage. In a simpler sense, it is a distributed persistent volume manager, and not a storage system like SAN or NAS.

```shell
helm install directpv minio/directpv
```

## AIStor Server

### Install Operators

Install the Object Store Operator and its supporting resources.

```shell
helm install aistor minio/aistor-operator \
  --namespace aistor --create-namespace \
  --set license="<your-license-key>"
```

### License Configuration

To use the `aistor-operator`, you must pass a valid license via the `license` field.

> **Important:** Do **not** pass the encrypted license block (starts with `ZXlK...`). The operator expects a **valid JWT string** (typically starts with `eyJ...`).

#### Correct usage (decoded JWT):

```shell
helm install aistor minio/aistor-operator \
  --namespace aistor --create-namespace \
  --set license="eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCJ9..."
```

#### Incorrect usage (encrypted blob):

```shell
helm install aistor minio/aistor-operator \
  --namespace aistor --create-namespace \
  --set license="ZXlKaGJHY2lPaUpGVXpNNE5DSXNJ..."
```

If you are unsure how to get the decoded license token (JWT), please contact your support representative or open a SUBNET request.

### AIStor Object Store

Create a new Object Store using the default Helm values.

```shell
helm install my-objectstore minio/aistor-objectstore \
  --namespace my-objectstore \
  --create-namespace
```

## AIStor Key Manager

A highly available, powerful and operationally simple key management server optimized for large storage infrastructures.

## AIStor Key Manager Operator

```shell
helm install keymanager-operator minio/minkms-operator \
  --namespace keymanager --create-namespace
```

### Create HSM key

Create an HSM key used for protecting all KMS data on disk:

```shell
docker run quay.io/minio/aistor/minkms:latest --soft-hsm
```

The command prints the generated HSM key to stdout, for example:

```
hsm:aes256:HSMKEYVALUE
```

### Install MinKMS

Deploy the Key Manager. Replace the `HSMKEYVALUE` in the example with the value from the previous step.

```shell
helm install my-keymanager minio/minkms \
  --namespace my-keymanager \
  --create-namespace \
  --set minkms.hsm.key="hsm:aes256:HSMKEYVALUE"
```

## AIStor WARP Operator

The AIStor WARP Operator is responsible for managing the AIStor WARP.
To install the AIStor WARP Operator, you can use the following command to opt-in to the AIStor WARP Operator in the
`minio/aistor-operator` Helm chart:

```shell
helm install aistor minio/aistor-operator \
  --namespace aistor --create-namespace \
  --set license="<your-license-key>" \
  --set operators.object-store.disabled=true \
  --set operators.adminjob.disabled=true \
  --set operators.warp.disabled=false
```

## Help and support

For help and support, open a ticket in SUBNET https://subnet.min.io/.
