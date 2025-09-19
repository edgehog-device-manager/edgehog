<!---
  Copyright 2021-2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Deploying with Kubernetes

Edgehog was designed as a Kubernetes native application, this guide will show how to deploy an
Edgehog instance in a Kubernetes cluster.

*Note: currently Edgehog requires some manual initialization operations to be performed in the
Elixir interactive shell and is not completely automated. All required operations are detailed
below in the guide.*

## Requirements

- A Kubernetes cluster
- `kubectl` correctly configured to target the aforementioned cluster
- An Ingress Controller deployed in the cluster (the guide contains examples for the NGINX Ingress
  Controller)
- An Astarte instance, with an existing realm and its private key
- A PostgreSQL v13+ database
- S3-compatible storage with its credentials
- The `jq` utility installed in the system
- (Optional) A Google Geolocation API Key
- (Optional) A Google Geocoding API Key
- (Optional) An ipbase.com API Key

The guide does not cover in detail how Edgehog is exposed to the internet, since administrators are
free to use their favorite Ingress Controller to achieve that. An example Ingress using the NGINX
Ingress Controller is provided, but advanced operations (e.g. certificate management) are out of the
scope of this guide.

The guide assumes everything is deployed to the `edgehog` namespace in the Kubernetes cluster, but
Edgehog can be deployed in any namespace adjusting the `yaml` files and the commands accordingly.

All fields that have to be customized will be indicated `<WITH-THIS-SYNTAX>`.

## Deploying Edgehog

This part of the guide will detail all the operations to deploy Edgehog into an existing Kubernetes
cluster.

### Namespace

First of all, the `edgehog` namespace has to be created

```bash
$ kubectl create namespace edgehog
```

### Installing NGINX Ingress Controller and cert-manager (example)

At this point you should install an Ingress Controller in your cluster. As an example, we will show
the procedure to install the NGINX Ingress Controller and cert-manager (to manager SSL certificates)
using `helm`. To do so, use these commands

```bash
$ helm repo add jetstack https://charts.jetstack.io
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
$ helm repo update
$ helm install cert-manager jetstack/cert-manager \
  --create-namespace --namespace cert-manager --set installCRDs=true
$ helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace --namespace ingress-nginx
```

After some minutes, you can retrieve the Load Balancer IP with

```bash
$ kubectl get svc -n ingress-nginx
```

in the `EXTERNAL-IP` column.

Note that NGINX is only one of the possible Ingress Controllers, instructions for other Ingress
Controllers are outside the scope of this guide.

### Creating DNS entries

Once you have the Load Balancer IP (obtained in the [previous
step](#installing-nginx-ingress-controller-and-cert-manager-example)), head to your DNS provider and
point three domains (one for the backend, one for the frontend, and one for the [Device Forwarder](https://github.com/edgehog-device-manager/edgehog_device_forwarder)) to that IP address.

Save the three hosts (e.g. `api.edgehog.example.com`, `edgehog.example.com`, and `forwarder.edgehog.example.com`) since they're going to be needed for the following steps.

### Secrets

A series of secrets containing various credentials have to be created.

#### Admin API authentication

Edgehog's backend exposes an Admin Rest API used to provision and manage tenants.
We need to seed some credentials to setup authentication for these APIs.

Specifically, a cryptographic keypair is needed to emit and validate auth tokens. You can generate an EC keypair with the following OpenSSL commands

```bash
$ openssl ecparam -name prime256v1 -genkey -noout > admin_private.pem
$ openssl ec -in admin_private.pem -pubout > admin_public.pem
```

After those commands are executed, you will have two files: `admin_private.pem` and `admin_public.pem`.
The `admin_private.pem` key is used to generate auth tokens to access the Admin API, and it is meant to be kept private.
The content of `admin_public.pem` will instead be used by Edgehog to validate incoming API requests.

To provide Edgehog's backend with the public key, create a Kubernetes secret containing the key which will be used later on in the deployment.

```bash
kubectl create secret generic edgehog-admin-api-public-key --from-file=admin_public.pem=./admin_public.pem
```

#### Database connection

This command creates the secret containing the details for the database connection:

```bash
$ kubectl create secret generic -n edgehog edgehog-db-connection \
  --from-literal="database=<DATABASE-NAME>" \
  --from-literal="username=<DATABASE-USER>" \
  --from-literal="password=<DATABASE-PASSWORD>"
```

Values to be replaced
- `DATABASE-NAME`: the name of the PostgreSQL database.
- `DATABASE-USER`: the username to access the database.
- `DATABASE-PASSWORD`: the password to access the database.

#### Secret key base

This command creates the secret key base used by Phoenix for the backend:

```bash
$ kubectl create secret generic -n edgehog edgehog-secret-key-base \
  --from-literal="secret-key-base=$(openssl rand -base64 48)"
```

Another secret key base can be generated for the device forwarder:

```bash
$ kubectl create secret generic -n edgehog edgehog-device-forwarder-secret-key-base \
  --from-literal="secret-key-base=$(openssl rand -base64 48)"
```

#### S3 Credentials (Google Cloud)

To create an S3-compatbile bucket on Google Cloud to be used with Edgehog, the following steps have
to be performed:

- [Create a service
  account](https://cloud.google.com/iam/docs/creating-managing-service-accounts#creating) in your
  project.

- [Create JSON
credentials](https://cloud.google.com/iam/docs/creating-managing-service-account-keys#creating) for
the service account and rewrite them as a single line JSON:

```bash
$ gcloud iam service-accounts keys create service_account_credentials.json \
  --iam-account=<SERVICE-ACCOUNT-EMAIL>
$ cat service_account_credentials.json | jq -c > s3_credentials.json
```

- [Create a Cloud Storage Bucket](https://cloud.google.com/storage/docs/creating-buckets) on GCP
   * Choose a multiregion in the preferred zones (e.g. Europe)
   * Remove public access prevention
   * Choose a fine-grained Access Control, instead of a uniform one

- After making sure of having the right project selected for the `gcloud` CLI, assign the
`objectAdmin` permission to the service account for the newly created bucket:

```bash
$ gsutil iam ch serviceAccount:<SERVICE-ACCOUNT-EMAIL>:objectAdmin gs://<BUCKET-NAME>
```

- Create a secret containing the service account credentials

```bash
$ kubectl create secret generic -n edgehog edgehog-s3-credentials \
  --from-file="gcp-credentials=s3_credentials.json"
```

Values to be replaced
- `SERVICE-ACCOUNT-EMAIL`: the email associated with the service account.
- `BUCKET-NAME`: the bucket name for the S3 storage.

#### S3 Credentials (Generic)

Consult the documentation of your cloud provider for more details about obtaining an access key ID
and a secret access key for your S3-compatible storage.

This command creates the secret containing the S3 credentials:

```bash
$ kubectl create secret generic -n edgehog edgehog-s3-credentials \
  --from-literal="access-key-id=<ACCESS-KEY-ID>" \
  --from-literal="secret-access-key=<SECRET-ACCESS-KEY>"
```

Values to be replaced
- `ACCESS-KEY-ID`: the access key ID for your S3 storage.
- `SECRET-ACCESS-KEY`: the secret access key for your S3 storage.

#### Azure Blob Credentials

To get started, follow the 
[documentation](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal#create-a-container)
to create a container.

Then, you can create a secret containing your connection string:

```bash
$ kubectl create secret generic -n edgehog edgehog-azure-credentials \
  --from-literal="connection-string=<CONNECTION-STRING>"
```

#### Google Geolocation API Key (optional)

Activate the Geolocation API for your project in GCP and
[create an API key](https://developers.google.com/maps/documentation/geolocation/get-api-key) to be
used with Google Geolocation.

After that, create the secret containing the API key with:

```bash
$ kubectl create secret generic -n edgehog edgehog-google-geolocation-credentials \
  --from-literal="api-key=<API-KEY>" \
```

Values to be replaced
- `API-KEY`: the Google Geolocation API Key obtained from GCP.

#### Google Geocoding API Key (optional)

Activate the Geocoding API for your project in GCP and
[create an API key](https://developers.google.com/maps/documentation/geocoding/get-api-key) to be
used with Google Geocoding.

After that, create the secret containing the API key with:

```bash
$ kubectl create secret generic -n edgehog edgehog-google-geocoding-credentials \
  --from-literal="api-key=<API-KEY>"
```

Values to be replaced
- `API-KEY`: the Google Geocoding API Key obtained from GCP.

#### ipbase.com API Key (optional)

Register an account at [ipbase.com](https://ipbase.com/) to obtain an API key.

After that, create the secret containing the API key with:

```bash
$ kubectl create secret generic -n edgehog edgehog-ipbase-credentials \
  --from-literal="api-key=<API-KEY>"
```

Values to be replaced
- `API-KEY`: the API Key obtained from ipbase.com.

### Deployments

After secrets are deployed, the deployments can be applied to the cluster.

#### Backend

To deploy the backend, copy the following `yaml` snippet in `backend-deployment.yaml`, fill the
missing values (detailed below) and execute

```bash
$ kubectl apply -f backend-deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: edgehog-backend
  name: edgehog-backend
  namespace: edgehog
spec:
  replicas: 1
  selector:
    matchLabels:
      app: edgehog-backend
  template:
    metadata:
      labels:
        app: edgehog-backend
    spec:
      containers:
      - env:
        - name: RELEASE_NAME
          value: edgehog
        - name: PORT
          value: "4000"
        - name: URL_HOST
          value: <BACKEND-HOST>
        - name: DATABASE_HOSTNAME
          value: <DATABASE-HOSTNAME>
        - name: DATABASE_NAME
          valueFrom:
            secretKeyRef:
              key: database
              name: edgehog-db-connection
        - name: DATABASE_USERNAME
          valueFrom:
            secretKeyRef:
              key: username
              name: edgehog-db-connection
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              key: password
              name: edgehog-db-connection
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              key: secret-key-base
              name: edgehog-secret-key-base
        - name: MAX_UPLOAD_SIZE_BYTES
          value: "<MAX-UPLOAD-SIZE-BYTES>"

        # Uncomment this env if you have installed an optional ipbase.com API Key in the secrets
        #
        #- name: IPBASE_API_KEY
        #  valueFrom:
        #    secretKeyRef:
        #      key: api-key
        #      name: edgehog-ipbase-credentials

        # Uncomment this env if you have installed an optional Google Geolocation API Key in the
        # secrets
        #
        #- name: GOOGLE_GEOLOCATION_API_KEY
        #  valueFrom:
        #    secretKeyRef:
        #      key: api-key
        #      name: edgehog-google-geolocation-credentials

        # Uncomment these envs if you have installed an optional Google Geocoding API Key in
        # the secrets
        #- name: GOOGLE_GEOCODING_API_KEY
        #  valueFrom:
        #    secretKeyRef:
        #      key: api-key
        #      name: edgehog-google-geocoding-credentials

        - name: S3_GCP_CREDENTIALS
          valueFrom:
            secretKeyRef:
              key: gcp-credentials
              name: edgehog-s3-credentials

        # If you're using another S3 provider which is not Google Cloud, uncomment these envs and
        # delete the previous env
        #
        #- name: S3_ACCESS_KEY_ID
        # valueFrom:
        #   secretKeyRef:
        #     key: access-key-id
        #     name: edgehog-s3-credentials
        #- name: S3_SECRET_ACCESS_KEY
        # valueFrom:
        #   secretKeyRef:
        #     key: secret-access-key
        #     name: edgehog-s3-credentials

        - name: S3_SCHEME
          value: <S3-SCHEME>
        - name: S3_HOST
          value: <S3-HOST>
        - name: S3_PORT
          value: "<S3-PORT>"
        - name: S3_BUCKET
          value: <S3-BUCKET>
        - name: S3_ASSET_HOST
          value: <S3-ASSET-HOST>
        - name: S3_REGION
          value: <S3-REGION>
        - name: EDGEHOG_FORWARDER_HOSTNAME
          value: <EDGEHOG-FORWARDER-HOSTNAME>
        - name: EDGEHOG_FORWARDER_PORT
          value: <EDGEHOG-FORWARDER-PORT>
        - name: EDGEHOG_FORWARDER_SECURE_SESSIONS
          value: <EDGEHOG-FORWARDER-SECURE-SESSIONS>

        # If you're using Azure instead, use the following configuration instead of the S3
        # configuration above
        # - name: STORAGE_TYPE
        #   value: azure
        # - name: AZURE_CONNECTION_STRING
        #   valueFrom:
        #     secretKeyRef:
        #       name: edgehog-azure-credentials
        #       key: connection-string 
        # - name: AZURE_CONTAINER
        #   value: <AZURE_CONTAINER>

        # You can also use standalone values instead of a connection string
        # - name: AZURE_REGION
        #   value: <AZURE_REGION>
        # - name: AZURE_STORAGE_ACCOUNT_NAME
        #   value: <AZURE_STORAGE_ACCOUNT_NAME>
        # - name: AZURE_STORAGE_ACCOUNT_KEY
        #   value: <AZURE_STORAGE_ACCOUNT_KEY>
        # - name: AZURE_BLOB_ENDPOINT
        #   value: <AZURE_BLOB_ENDPOINT>

        - name: ADMIN_JWT_PUBLIC_KEY_PATH
          value: /keys/admin_public.pem
        volumeMounts:
        - name: admin-public-key
          mountPath: /keys
          readOnly: true
        image: edgehogdevicemanager/edgehog-backend:0.9.3
        imagePullPolicy: Always
        name: edgehog-backend
        ports:
        - containerPort: 4000
          name: http
          protocol: TCP
      volumes:
      - name: admin-public-key
        secret:
          secretName: edgehog-admin-api-public-key
          items:
          - key: admin_public.pem
            path: admin_public.pem
```

Values to be replaced
- `BACKEND-HOST`: the host of the Edgehog backend (see the [Creating DNS
  entries](#creating-dns-entries) section).
- `DATABASE-HOSTNAME`: the hostname of the PostgreSQL database.
- `MAX-UPLOAD-SIZE-BYTES`: the maximum dimension for uploads, particularly relevant for OTA updates.
  If omitted, it defaults to 4 Gigabytes.
- `S3-SCHEME`: the scheme (`http` or `https`) for the S3 storage.
- `S3-HOST`: the host for the S3 storage.
- `S3-PORT`: the port for the S3 storage. This has to be put in double quotes to force it to be
  interpreted as a string.
- `S3-BUCKET`: the bucket name for the S3 storage.
- `S3-ASSET-HOST`: the asset host for the S3 storage, e.g. `storage.googleapis.com/<S3-BUCKET>` for
  GCP or `<S3-BUCKET>.s3.amazonaws.com` for AWS.
- `S3-REGION`: the region where the S3 storage resides.
- `EDGEHOG-FORWARDER-HOSTNAME`: the host for the instance of [Edgehog Device Forwarder](https://github.com/edgehog-device-manager/edgehog_device_forwarder). It should only contain the hostname without the `http://` or `https://` scheme.
- `EDGEHOG-FORWARDER-PORT`: the port for the instance of [Edgehog Device Forwarder](https://github.com/edgehog-device-manager/edgehog_device_forwarder). It defaults to `443`.
- `EDGEHOG-FORWARDER-SECURE-SESSIONS`: either `true` or `false`, indicates whether devices use TLS to connect to the [Edgehog Device Forwarder](https://github.com/edgehog-device-manager/edgehog_device_forwarder). It defaults to `true`.

The optional env variable in the `yaml` also have to be uncommented where relevant (see comments
above the commented blocks for more information).

#### Frontend

To deploy the frontend, copy the following `yaml` snippet in `frontend-deployment.yaml`, fill the
missing values (detailed below) and execute

```bash
$ kubectl apply -f frontend-deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: edgehog-frontend
  name: edgehog-frontend
  namespace: edgehog
spec:
  replicas: 1
  selector:
    matchLabels:
      app: edgehog-frontend
  template:
    metadata:
      labels:
        app: edgehog-frontend
    spec:
      containers:
      - env:
        - name: BACKEND_URL
          value: <BACKEND-HOST>
        image: edgehogdevicemanager/edgehog-frontend:0.9.3
        imagePullPolicy: Always
        name: edgehog-frontend
        ports:
        - containerPort: 80
          name: httpout
          protocol: TCP
```

Values to be replaced
- `BACKEND-URL`: the API base URL of the Edgehog backend (see the [Creating DNS
  entries](#creating-dns-entries) section). This should be, e.g., `https://<BACKEND-HOST>`.

#### Device Forwarder

To deploy the device forwarder, copy the following `yaml` snippet in `device-forwarder-deployment.yaml`, fill the
missing values (detailed below) and execute

```bash
$ kubectl apply -f device-forwarder-deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: edgehog-device-forwarder
  name: edgehog-device-forwarder
  namespace: edgehog
spec:
  replicas: 1
  selector:
    matchLabels:
      app: edgehog-device-forwarder
  template:
    metadata:
      labels:
        app: edgehog-device-forwarder
    spec:
      containers:
      - env:
        - name: RELEASE_NAME
          value: edgehog-device-forwarder
        - name: PORT
          value: "4000"
        - name: PHX_HOST
          value: <DEVICE-FORWARDER-HOST>
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              key: secret-key-base
              name: edgehog-device-forwarder-secret-key-base
        image: edgehogdevicemanager/edgehog-device-forwarder:0.1.0
        imagePullPolicy: Always
        name: edgehog-device-forwarder
        ports:
        - containerPort: 4000
          name: http
          protocol: TCP
```

Values to be replaced
- `DEVICE-FORWARDER-HOST`: the host of the Edgehog Device Forwarder (see the [Creating DNS entries](#creating-dns-entries) section).

### Services

#### Backend

To deploy the backend service, copy the following `yaml` snippet in `backend-service.yaml` and
execute

```bash
$ kubectl apply -f backend-service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: edgehog-backend
  name: edgehog-backend
  namespace: edgehog
spec:
  ports:
  - port: 4000
    protocol: TCP
    targetPort: 4000
  selector:
    app: edgehog-backend
```

#### Frontend

To deploy the frontend service, copy the following `yaml` snippet in `frontend-service.yaml` and
execute 

```bash
$ kubectl apply -f frontend-service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: edgehog-frontend
  name: edgehog-frontend
  namespace: edgehog
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: edgehog-frontend
```

#### Device Forwarder

To deploy the device forwarder service, copy the following `yaml` snippet in `device-forwarder-service.yaml` and
execute

```bash
$ kubectl apply -f device-forwarder-service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: edgehog-device-forwarder
  name: edgehog-device-forwarder
  namespace: edgehog
spec:
  ports:
  - port: 4000
    protocol: TCP
    targetPort: 4000
  selector:
    app: edgehog-device-forwarder
```

### Exposing Edgehog to the Internet

#### SSL Certificates

This is an example certificates configuration for Edgehog. This is provided as a starting point and
it uses `certmanager` to obtain LetsEncrypt SSL certificates. All advanced topics (advanced
certificate management, self-provided certificates) are not discussed here and are outside the scope
of this guide.

First of all, create a `ClusterIssuer` by copying the following `yaml` snippet in
`cluster-issuer.yaml` and executing

```bash
$ kubectl apply -f cluster-issuer.yaml
```

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: <EMAIL-ADDRESS>
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
```

Values to be replaced
- `EMAIL-ADDRESS`: a valid email address that will be used for the ACME account for LetsEncrypt.

After that, create a certificate for your frontend and backend hosts, copying the following `yaml`
snippet in `certificate.yaml` and executing

```bash
$ kubectl apply -f certificate.yaml
```

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tls-secret
  namespace: edgehog
spec:
  secretName: tls-secret
  dnsNames:
  - <FRONTEND-HOST>
  - <BACKEND-HOST>
  - <DEVICE-FORWARDER-HOST>
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: letsencrypt
```

Values to be replaced
- `FRONTEND-HOST`: the frontend host.
- `BACKEND-HOST`: the backend host.
- `DEVICE-FORWARDER-HOST`: the device forwarder host.

Note that this step must be performed after DNS for the frontend and backend hosts are correctly
propagated (see [Creating DNS Entries](#creating-dns-entries)).

#### Ingress

This is an example Ingress configuration for Edgehog. This is provided as a starting point and it
uses the NGINX Ingress Controller. All advanced topics (e.g. certificate management) are not discussed here
and are outside the scope of this guide.

Copy this `yaml` snippet to `ingress.yaml` and execute

```bash
$ kubectl apply -f ingress.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: <MAX-UPLOAD-SIZE>
    nginx.ingress.kubernetes.io/proxy-read-timeout: "120"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "120"
  name: edgehog-ingress
  namespace: edgehog
spec:
  rules:
  - host: <FRONTEND-HOST>
    http:
      paths:
      - backend:
          service:
            name: edgehog-frontend
            port:
              number: 80
        path: /
        pathType: Prefix
  - host: <BACKEND-HOST>
    http:
      paths:
      - backend:
          service:
            name: edgehog-backend
            port:
              number: 4000
        path: /
        pathType: Prefix
  - host: <DEVICE-FORWARDER-HOST>
    http:
      paths:
      - backend:
          service:
            name: edgehog-device-forwarder
            port:
              number: 4000
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - <FRONTEND-HOST>
    - <BACKEND-HOST>
    - <DEVICE-FORWARDER-HOST>
    secretName: tls-secret
```

Values to be replaced
- `FRONTEND-HOST`: the frontend host.
- `BACKEND-HOST`: the backend host.
- `DEVICE-FORWARDER-HOST`: the device forwarder host.
- `MAX-UPLOAD-SIZE`: the maximum upload size that you defined in the [Edgehog backend
  deployment](https://edgehog-device-manager.github.io/docs/0.9/deploying_with_kubernetes.html#deployments).
  Note that NGINX accepts also size suffixes, so you can put, e.g., `4G` for 4 gigabytes. Also note
  that, differently from the value in the Deployment, this is required because NGINX default is 1
  megabyte.

Note that we are setting `proxy-read-timeout` and `proxy-send-timeout` to 120 seconds.
This value represents the timeout after which inactive connections are terminated.
This configuration has implications on the inactive sessions of the Device Forwarder: the forwarder has its own default timeout of 1 minute for terminating inactive WebSocket connections, and setting a lower timeout here would conflict with the forwarder's internal processes. For this reason, we leave that responsibility to the forwarder by setting a slightly higher timeout here, such as 2 minutes.
When changing the value, one should also evaluate the implications on connections to Edgehog's frontend and backend. In addition, higher values may lead to higher risk of DoS attacks. 

## Creating an Edgehog tenant

By now, Edgehog should already be properly initialized and we are ready to create our first tenant.

We first need to have a backing Astarte instance with an already existing Astarte realm which will be a 1:1 match with the Edgehog tenant.

Then we can create the Edgehog tenant with a couple of steps.

### Creating a key pair for the tenant

A cryptographic keypair is needed to emit and validate tokens to access your tenant. 
You can generate an EC keypair with the following OpenSSL commands

```bash
$ openssl ecparam -name prime256v1 -genkey -noout > tenant_private.pem
$ openssl ec -in tenant_private.pem -pubout > tenant_public.pem
```

### Creating a tenant with the Admin API

The next step is generating a token to access Edgehog Admin Rest API. You can do so using the `gen-edgehog-jwt` tool contained in the
`tools` directory of the [Edgehog
repo](https://github.com/edgehog-device-manager/edgehog/tree/main/tools).
Starting from the private key we generated earlier in the deployment process for the Admin API, `admin_public.pem`, this command should give you a valid auth token to access the API.

```bash
$ pip3 install pyjwt
$ ./gen-edgehog-jwt -t admin -k <PATH-TO-ADMIN-PRIVATE-KEY>
```

Note that the token expires after 24 hours by default. If you want to have a token with a different expiry time, you can pass `-e <EXPIRY-SECONDS>` to the `gen-edgehog-jwt` command.

You can test the auth token by listing the existing tenants in the Edgehog instance:

```bash
curl -X GET --location 'https://<EDGEHOG-API-HOST>/admin-api/v1/tenants' \
--header 'Content-Type: application/vnd.api+json' \
--header 'Authorization: Bearer <ADMIN-TOKEN>'
```

Then, to actually create the tenant:

```bash
curl -X POST --location 'https://<BACKEND-HOST>/admin-api/v1/tenants' \
--header 'Content-Type: application/vnd.api+json' \
--header 'Authorization: Bearer <ADMIN-TOKEN>' \
--data '{
  "data": {
    "attributes": {
      "astarte_config": {
        "base_api_url": "<ASTARTE-BASE-API-URL>",
        "realm_name": "<ASTARTE-REALM-NAME>",
        "realm_private_key": <ASTARTE-REALM-PRIVATE-KEY>
      },
      "default_locale": "en-US",
      "name": "<TENANT-NAME>",
      "public_key": "<TENANT-PUBLIC-KEY>",
      "slug": "<TENANT-SLUG>"
    },
    "relationships": {},
    "type": "tenant"
  }
}'
```

Values to be replaced
- `BACKEND-HOST`: the domain which exposes Edgehog API. This is the same as `BACKEND-HOST` from the Ingress definition.
- `ADMIN-TOKEN`: the auth token generated from the admin private key to access Edgehog Admin API.
- `TENANT-NAME`: the name of the new tenant.
- `TENANT-SLUG`: the slug of the tenant, must contain only lowercase letters and hyphens.
- `TENANT-PUBLIC-KEY`: the content of `tenant_public.pem` created in the previous
  step.
- `ASTARTE-BASE-API-URL`: the base API url of the Astarte instance (e.g.
  https://api.astarte.example.com).
- `ASTARTE-REALM-NAME`: the name of the Astarte realm you're using.
- `ASTARTE-REALM-PRIVATE-KEY`: the content of the Astarte realm's private key.

### Creating a tenant with an iEx session

If the Admin API cannot be used for some reason, an alternative way can be to establish a live terminal session with Edgehog's backend and issue commands in the Elixir shell.

Connect to the `iex` interactive shell of the Edgehog backend using

```bash
$ kubectl exec -it deploy/edgehog-backend -n edgehog -- /app/bin/edgehog remote
```

All the following commands have to be executed inside that shell, in a single session (since some
commands will reuse the result of previous commands)

The following commands will create a database entry representing the tenant, with its associated
Astarte cluster and Realm.

```elixir
iex> alias Edgehog.Tenants
iex> tenant_name = "<TENANT-NAME>"
iex> tenant_slug = "<TENANT-SLUG>"
iex> tenant_public_key = """
<TENANT-PUBLIC-KEY>
"""
iex> base_api_url = "<ASTARTE-BASE-API-URL>"
iex> realm_name = "<ASTARTE-REALM-NAME>"
iex> realm_private_key = """
<ASTARTE-REALM-PRIVATE-KEY>
"""
iex> {:ok, tenant} = Tenants.provision_tenant(
  %{
    name: tenant_name,
    slug: tenant_slug,
    public_key: tenant_public_key,
    astarte_config: %{
      base_api_url: base_api_url,
      realm_name: realm_name,
      realm_private_key: realm_private_key
    }
  })
```

Values to be replaced
- `TENANT-NAME`: the name of the new tenant.
- `TENANT-SLUG`: the slug of the tenant, must contain only lowercase letters and hyphens.
- `TENANT-PUBLIC-KEY`: the content of `tenant_public.pem` created in the [previous
  step](#creating-a-keypair). Open a multiline string with `"""`, press Enter, paste the content of
  the file in the `iex` shell and then close the multiline string with `"""` on a new line.
- `ASTARTE-BASE-API-URL`: the base API url of the Astarte instance (e.g.
  https://api.astarte.example.com).
- `ASTARTE-REALM-NAME`: the name of the Astarte realm you're using.
- `ASTARTE-REALM-PRIVATE-KEY`: the content of the Astarte realm's private key. Open a multiline string with
  `"""`, press Enter, paste the content of the file in the `iex` shell and then close the multiline
  string with `"""` on a new line.

## Accessing the Edgehog tenant

At this point the Edgehog instance should be ready and healthy, with an existing tenant.

To access the tenant we can once more use the `gen-edgehog-jwt` tool contained in the
`tools` directory of the [Edgehog
repo](https://github.com/edgehog-device-manager/edgehog/tree/main/tools).

```bash
$ pip3 install pyjwt
$ ./gen-edgehog-jwt -t tenant -k <PATH-TO-TENANT-PRIVATE-KEY>
```

Values to be replaced
- `PATH-TO-TENANT-PRIVATE-KEY`: path to the `tenant_private.pem` file created in the [previous
  step](#creating-a-key-pair-for-the-tenant).

Note that the token expires after 24 hours by default. If you want to have a token with a different
expiry time, you can pass `-e <EXPIRY-SECONDS>` to the `gen-edgehog-jwt` command.

After that, you can open your frontend URL in your browser and insert your tenant slug and token to
log into your Edgehog instance, and use to the [user guide](intro_user.html) to discover all Edgehog
features.
