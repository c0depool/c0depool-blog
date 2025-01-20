---
title: "Authentik with Kubernetes: Forward Authentication using Ingress Nginx"
date: 2025-01-19 00:59:00 +0000
categories: [Self-Hosting]
tags: [self-hosting,k8s,authentik,authentication,sso,nginx,ingress]
pin: false
image:
  path: /assets/img/2025-01-19-authentik-with-kubernetes-forward-auth/authentik-k8s-nginx.webp
  lqip: data:image/webp;base64,UklGRkwAAABXRUJQVlA4IEAAAAAwAgCdASoQAAsABUB8JYgCdAEWYTn7mTbRQAD+SY/P5f3EOCmWhWgW82wj8Ei+aqzT4WE5kkTykE8rgWjEgAAA
  alt: "Authentik with Kubernetes: Forward Authentication using Ingress Nginx"
---

Building my own home server and tinkering with it has always been a satisfying hobby, even if it means creating over-engineered solutions to problems that don't really exist. Despite the occasional chaos, there's something deeply rewarding about the process of self-hosting. As my _user base_ grew from a single digit to a larger single digit, it became evident that centralized identity management was necessary. So, I finally decided to deploy [Authentik](https://goauthentik.io/) to my Kubernetes cluster.

Authentik is an [awesome](https://github.com/awesome-foss/awesome-sysadmin?tab=readme-ov-file#identity-management---single-sign-on-sso) open-source identity provider that supports protocols like OAuth2, SAML, LDAP and forward authentication. I was particularly interested in forward authentication because several of my services lacked built-in authentication support. By integrating Authentik with my ingress-nginx, I was hoping for a smooth single sign-on (SSO) experience, but it quickly became clear that my over-engineered setup had other plans. As always, I'm documenting the steps I took and the mistakes I made, so you don't have to make the same ones (hopefully).

## Prerequisites

- A kubernetes cluster, can be single or multi node, bare-metal or cloud. I used my [Talos](https://www.talos.dev/) k8s v1.30.2 cluster for this guide.
- A working [ingress-nginx](https://github.com/kubernetes/ingress-nginx) as the ingress controller.
- A custom domain, public or locally resolved. Assumed as `yourdomain.com` in this guide.
- [Helm](https://helm.sh/).
- A linux VM which acts as a workstation/bastion. In this guide, we use Debian 11.
- Basic understanding of Linux, Containers and Kubernetes.

## Installing Authentik using Helm

Let us start by installing Authentik using the helm chart by following the official [documentation](https://docs.goauthentik.io/docs/installation/kubernetes).

1. Generate a 60 character random string for the Authentik `secure_key`.
```bash
openssl rand 60 | base64 -w 0
```
2. Create a `values.yaml`.
```yaml
   authentik:
     secret_key: "<secure_key generated in step 1>"
     postgresql:
       password: "<a strong password for the db, same as postgresql.auth.password>"
   server:
     ingress:
       enabled: true
       ingressClassName: nginx
       hosts:
         - "auth.<your domain>"
       tls:
         - secretName: "<your TLS secret>"
           hosts:
           - "auth.<your domain>"
   postgresql:
     enabled: true
     auth:
       password: "<a strong password for the db>"
   redis:
     enabled: true
```
3. Install the helm chart using the `values.yaml`.
```bash
helm repo add authentik https://charts.goauthentik.io
helm repo update
helm upgrade --install authentik authentik/authentik -f values.yaml --namespace authentik --create-namespace
```
4. Check the pod status, everything should be in "Running" state.
```bash
kubectl get pods -n authentik
```
5. Once the installation is complete, access authentik at `https://auth.yourdomain.com/if/flow/initial-setup/` and setup the password for `akadmin` user.
6. Navigate to System → Outpost Integrations, if there is no existing local `Kubernetes Service-Connection`, create one by clicking on `Create`. Select `Kubernetes Service-Connection`, give a name for the custer, enable local and click on `Finish`.
![authentik-update-integration](/assets/img/2025-01-19-authentik-with-kubernetes-forward-auth/authentik-update-integration.webp)
7. Navigate to Applications → Outposts → Edit `authentik Embedded Outpost` and update the integration filed with the kubernetes integration you have created in the previous step.
![authentik-update-outpost-integration](/assets/img/2025-01-19-authentik-with-kubernetes-forward-auth/authentik-update-outpost-integration.webp)
8. Optionally, you can expand the `Advanced settings` section and update details of your cluster such as `authentik_host`, `kubernetes_ingress_class_name`, `kubernetes_ingress_secret_name` etc. Once done, click on update.

## Setup Forward Authentication for Ingress Nginx

1. For the purpose of this guide, let us create a simple hello-world pod with an ingress and enable authentication for it. Create below YAML manifest `hello-world.yaml` for the resources.
```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: hello-world-pod
     labels:
       app: hello-world
   spec:
     containers:
       - name: hello-world-container
         image: crccheck/hello-world
         ports:
           - containerPort: 8000
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: hello-world-service
   spec:
     selector:
       app: hello-world
     ports:
       - protocol: TCP
         port: 80
         targetPort: 8000
   ---
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: hello-world-ingress
   spec:
     ingressClassName: nginx
     rules:
       # Update host with your domain name
       - host: hello.yourdomain.com
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: hello-world-service
                   port:
                     number: 80
     # Optionally configure TLS
     tls:
       - hosts:
         - hello.yourdomain.com
         secretName: your-tls-secret
```
2. Apply the manifest on the default namespace.
```bash
kubectl apply -f hello-world.yaml
```
3. Verify that the ingress works. Use curl or open the url `https://hello.yourdomain.com` (use `http://` if you haven't configured TLS) in a browser.
```bash
curl hello.yourdomain.com -L
# Should return:
# <pre>
# Hello World
#
#
#                                        ##         .
#                                  ## ## ##        ==
#                               ## ## ## ## ##    ===
#                            /""""""""""""""""\___/ ===
#                       ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~
#                            \______ o          _,/
#                             \      \       _,'
#                              `'--.._\..--''
# </pre>
```
4. Open `https://auth.yourdomain.com` and login as `akadmin` user. Navigate to `Admin interface` by clicking on the button at top right corner.
5. Navigate to Applications → Providers → Create. Select `Proxy Provider` as the provider type and click on `Next`.
6. Give a name for your provider, select the `Authorization flow` from the dropdown (you can choose either one), select `Forward auth (single application)` and provide your URL at the `External host` field. Click on `Finish`.
![authentik-create-provider](/assets/img/2025-01-19-authentik-with-kubernetes-forward-auth/authentik-create-provider.webp)
7. Navigate to Applications → Applications → Create. Provide the application details, select the previously created `hello-world-provider` as provider and click on `Create`.
![authentik-create-application](/assets/img/2025-01-19-authentik-with-kubernetes-forward-auth/authentik-create-application.webp)
8. Navigate to Applications → Outposts → Edit `authentik Embedded Outpost` and add the hello-world application to the selected list of apps and click `Update`.
![authentik-update-outpost](/assets/img/2025-01-19-authentik-with-kubernetes-forward-auth/authentik-update-outpost.webp)
9. Edit your ingress configuration in `hello-world.yaml` to add the outpost details under metadata.annotations section.
```yaml
...
   metadata:
     name: hello-world-ingress
     annotations:
       nginx.ingress.kubernetes.io/auth-url: |-
          http://ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000/outpost.goauthentik.io/auth/nginx
       nginx.ingress.kubernetes.io/auth-signin: |-
          https://hello.yourdomain.com/outpost.goauthentik.io/start?rd=$escaped_request_uri
       nginx.ingress.kubernetes.io/auth-response-headers: |-
          Set-Cookie,X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid
       nginx.ingress.kubernetes.io/auth-snippet: |
          proxy_set_header X-Forwarded-Host $http_host;
...
```
10. Apply the configuration.
```bash
kubectl apply -f hello-world.yaml
```
11. Open the url `https://hello.yourdomain.com` in a browser and you should now be presented with the Authentik login page!

Congratulations, your Authentik forward-proxy should be (hopefully) working now! 

## Troubleshooting

Unfortunately, setting up Authentik with Kubernetes and ingress-nginx can be tricky and you might run into few errors. The key is to understand the authentication request flow and observe the logs when you browse the page. Here are some tips to troubleshoot some of the common errors.

- Make sure you have [allow-snippet-annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#allow-snippet-annotations) enabled by setting `controller.allowSnippetAnnotations` to `true` in your helm values for the ingress-nginx installation.
- You might also want to accept critical risks on [annotations-risk-level](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#annotations-risk-level) by setting `controller.config.annotations-risk-level` to `Critical` in your ingress-nginx helm values.

  > Please be aware of the [security implications](https://github.com/kubernetes/kubernetes/issues/126811) while allowing snippet annotations in ingress-nginx.
  {: .prompt-warning }

- If you are getting `404 Not Found`, `502 Bad Gateway` or `503 Service Temporarily Unavailable` while browsing the application URL, check ingress-nginx-controller and authentik-server pod logs for any errors. Watch the live logs in each pod using `--follow` with `kubectl logs` and see what happens when you browse the page.
- Enable debug logging in Authentik by setting up `authentik.log_level` to `trace` in the helm values.
- You can also edit the ingress controller deployment to enable debug logging by setting `--v=5` under `- args`. Check [this](https://github.com/kubernetes/ingress-nginx/blob/main/docs/troubleshooting.md#debug-logging) for more info.
- If you see errors like `ingress contains invalid paths: path /outpost.goauthentik.io cannot be used with pathType Prefix` in your ingress-nginx-controller logs, disable [strict-validate-path-type](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#strict-validate-path-type) by setting `controller.config.strict-validate-path-type` to `false` in ingress-nginx helm values. This is needed due to [this](https://github.com/kubernetes/ingress-nginx/issues/11176) issue. if you don't want Authentic to manage the outpost, you can manually create outpost ingresses.
- If you use custom http error pages by setting `controller.config.custom-http-errors` in ingress-nginx, make sure it is _not_ configured for `401` as Authentik needs to intercept these responses. Learnt that the hard way! 🙂
- If you use a local dns, make sure that your application URL is accessible from the nginx pod. You can test this by logging into the nginx container and running `curl`.
```bash
kubectl exec -n ingress-nginx -it <ingress-nginx-controller-pod-name> -- /bin/bash
# Once you are in the container
curl https://auth.yourdomain.com -Lk
curl https://hello.yourdomain.com -Lk
```
If it is not resolving (curl says `Could not resolve host`), you have to make sure DNS resolution is working from the cluster network. If you are using CoreDNS, check out [this](https://techdocs.akamai.com/cloud-computing/docs/coredns-custom-config) guide to add a custom DNS entry.
- You can check out my ingress-nginx [helm values](https://github.com/c0depool/c0depool-k8s-ops/blob/7942ca22bfe293ac25b4e331bb18c6dc9797f6e2/infrastructure/ingress-nginx/release.yaml#L20) and Authentik [helm values](https://github.com/c0depool/c0depool-k8s-ops/blob/7942ca22bfe293ac25b4e331bb18c6dc9797f6e2/infrastructure/authentik/release.yaml#L20) in my GitHub repository. 

I hope this guide helps save someone from losing their sanity while setting up Authentik! Peace. ✌️
