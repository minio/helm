# MinIO Helm Charts

Hyperscale Object Store for AI

MinIO AIStor is designed to allow enterprises to consolidate all of
their data on a single, private cloud namespace. Architected using
the same principles as the hyperscalers, AIStor delivers performance
at scale at a fraction of the cost compared to the public cloud.

AIStor runs in Kubernetes.

## Pre-requisites

* An active Kubernetes environment running a [maintained version](https://kubernetes.io/releases/)
* [`kubectl` CLI tool](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [`helm` CLI tool](https://helm.sh/docs/intro/install/)
* `oc` CLI tool if you are using Openshift

### Environment

You can run MinIO Helm charts on Kubernetes providers such as

- Redhat Openshift
- Upstream Kubernetes
- Google Kubernetes Engine
- Amazon Elastic Kubernetes Service
- Azure Kubernetes Service

Other Kubernetes providers may also work.

## MinIO Helm charts Repo

helm.min.io repo is the official MinIO Helm repo for the enterprise products. You can add it with the following command:
```shell
helm repo add minio https://helm.min.io/
helm repo update
```

When you add the repo, you can see the available charts with the following command:
```shell
helm search repo minio
NAME                             	CHART VERSION	APP VERSION        	DESCRIPTION                                      
minio/aistor-keymanager          	1.0.0        	                   	Helm chart for MinIO AIStor Key Manager          
minio/aistor-keymanager-operator 	1.0.0        	v20250603065135.0.0	Helm chart for MinIO AIStor Key Manager operator 
minio/aistor-objectstore         	1.0.3        	                   	Helm chart for MinIO AIStor Object Store         
minio/aistor-objectstore-operator	4.0.0        	v20250603065135.0.0	Helm chart for MinIO AIStor Object Store operator
minio/aistor-volumemanager       	0.1.0        	5.0.0              	DirectPV - AIStor Volume Manager          
```

## AIStor Volume Manager
AIStor Volume Manager is a CSI driver for Direct Attached Storage, `minio/aistor-volumemanager` is the AIStor Volume Manager chart.

You can install the AIStor Volume Manager CSI with the following command:

```shell
helm install directpv minio/aistor-volumemanager \
  --namespace aistor --create-namespace \
  --set global.license="<your-license-key>"
```

## AIStor Object Store Operator

`minio/aistor-objectstore-operator` is the AIStor Object Store operators chart, by default, it will install only 2 operators:

* AIStor Object Store Operator
* AIStor AdminJob Operator

You can install the AIStor operators with the following commands:

```shell
helm install aistor minio/aistor-objectstore-operator \
  --namespace aistor --create-namespace \
  --set global.license="<your-license-key>"
```

### 🔐 License Configuration

To use the `aistor-objectstore-operator`, you must pass a valid license via the `global.license` field.

> ⚠️ **Important:** Do **not** pass the encrypted license block (starts with `ZXlK...`). The operator expects a **valid JWT string** (typically starts with `eyJ...`).

#### ✅ Correct usage (decoded JWT):

```bash
helm install aistor minio/aistor-objectstore-operator \
  --namespace aistor --create-namespace \
  --set global.license="eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCJ9..."
```

#### ❌ Incorrect usage (encrypted blob):

```bash
helm install aistor minio/aistor-objectstore-operator \
  --namespace aistor --create-namespace \
  --set global.license="ZXlKaGJHY2lPaUpGVXpNNE5DSXNJ..."
```

If you are unsure how to get the decoded license token (JWT), please contact your support representative or open a SUBNET request.

### AIStor Object Store

Now you are ready to create your own AIStor object store, get the values.yaml file from the chart and edit it to your needs.

```shell
helm show values minio/aistor-objectstore > values.yaml
```

Finally, create the object store with the following command:

```shell
helm install my-objectstore minio/aistor-objectstore \
  --namespace my-objectstore \
  --create-namespace \
  -f values.yaml 
```

## AIStor Key Manager Operator

The AIStor Key Manager Operator is responsible for managing the AIStor Key Manager.
To install the AIStor Key Manager Operator, you can use the following command:

```shell
helm install keymanager-operator minio/aistor-keymanager-operator\
  --namespace keymanager \
  --create-namespace  \
  --set global.license="<your-license-key>" 
```

### AIStor Key Manager

Once Key Manager Operator is installed, you can create your own AIStor Key Manager, get the values.yaml file from the chart and edit it to your needs.

```shell
helm show values minio/aistor-keymanager > values.yaml
```

Next, you want to create the HSM master key, in order to do that, you need to create it running the `minkms` command, this is possible running it from the container:

```shell
docker run quay.io/minio/aistor/minkms:latest --soft-hsm
hsm:aes256:HSMKEYVALUE 
```

Finally, create the Key Manager with the following command, please replace the `HSMKEYVALUE` with the value generated by the `minkms --soft-hsm` command:

```shell
helm install my-keymanager minio/aistor-keymanager \
  --namespace my-keymanager \
  --create-namespace \
  --set  hsm.hsm="hsm:aes256:HSMKEYVALUE"
```

Replace the `HSMKEYVALUE` with the value generated by the `minkms --soft-hsm` command.

## AIStor AIHub Operator
The AIStor AIHub Operator is responsible for managing the AIStor AIHub.
To install the AIStor AIHub Operator, you can use the following command to opt-in to the AIStor AIHub Operator in the 
`minio/aistor-objectstore-operator` Helm chart:

```shell
helm install aistor minio/aistor-objectstore-operator \ 
  --namespace aistor \
  --create-namespace \
  --set global.license="<your-license-key>" \
  --set operators.object-store.disabled=true \
  --set operators.adminjob.disabled=true \
  --set operators.aihub.disabled=false
```

## AIStor Prompt Operator
The AIStor Prompt Operator is responsible for managing the AIStor Prompt.
To install the AIStor Prompt Operator, you can use the following command to opt-in to the AIStor AIHub Operator in the
`minio/aistor-objectstore-operator` Helm chart:

```shell
helm install aistor minio/aistor-objectstore-operator \
  --namespace aistor \
  --create-namespace \
  --set global.license="<your-license-key>" \
  --set operators.object-store.disabled=true \
  --set operators.adminjob.disabled=true \
  --set operators.prompt.disabled=false
```

## AIStor WARP Operator

The AIStor WARP Operator is responsible for managing the AIStor WARP.
To install the AIStor WARP Operator, you can use the following command to opt-in to the AIStor AIHub Operator in the
`minio/aistor-objectstore-operator` Helm chart:

```shell
helm install aistor minio/aistor-objectstore-operator \ 
  --namespace aistor \
  --create-namespace \
  --set global.license="<your-license-key>" \
  --set operators.object-store.disabled=true \
  --set operators.adminjob.disabled=true \
  --set operators.warp.disabled=false
```

### Help and support

For help and support, open a ticket in SUBNET https://subnet.min.io/.
