---
title: Automating Talos Installation on Proxmox with Packer and Terraform, Integrating Cilium and Longhorn
date: 2024-07-07 00:59:00 +0000
categories: [Self-Hosting]
tags: [self-hosting,proxmox,k8s,talos,talhelper,IaC,cilium,load-balancer,l2-announcement,longhorn]
pin: false
image:
  path: /assets/img/2024-07-07-automating-talos-installation-on-proxmox-with-packer-and-terraform/server-room.webp
  lqip: data:image/webp;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAJABADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDyq2jUNxTbtMNzUlp94UX/AFrToZ9T/9k=
  alt: "AI generated image of a server room with a ship's wheel in the center."
---

I recently migrated my home kubernetes [cluster](https://github.com/c0depool/c0depool-k8s-ops) from [K3s](https://k3s.io/) to [Talos](https://www.talos.dev/). While K3s was an excellent lightweight option for my home server, it required installing, hardening and maintaining a base operating system (Debian, in my case). As someone who frequently builds and destroys Kubernetes clusters - both intentionally and accidentally - my priority has always been to restore my services with minimal effort after a disaster. Talos, a minimalistic Linux distribution specifically designed for Kubernetes, tailored for automation, reliability and simplicity, seems to be a perfect fit for my needs. In this blog, I am documenting the steps I followed to install a six-node Talos cluster, serving as a future reference for myself and potentially helping others with similar projects.

## Features

- [Talos](https://www.talos.dev/): Cluster operating system.
- [Cilium](https://cilium.io/): Networking and L2 load balancer.
- [Ingress Nginx](https://github.com/kubernetes/ingress-nginx): Ingress controller.
- [Longhorn](https://longhorn.io/): Distributed storage.

## Prerequisites

- [Proxmox VE](https://www.proxmox.com/en/proxmox-virtual-environment/overview) cluster/standalone server.
- A linux VM which acts as a workstation/bastion. In this guide, we use Debian 11.
- Basic understanding of Linux, Containers and Kubernetes.

## Prepare the workstation

1. On your linux workstation install the tools required for this guide. Let us start off with [Packer](https://www.packer.io/).
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer
packer -v
```
2. Install [Terraform](https://www.terraform.io/)
```bash
sudo apt update
sudo apt install terraform
terraform -v
```
3. Install [Talosctl](https://www.talos.dev/v1.7/learn-more/talosctl/)
```bash
curl -sL https://talos.dev/install | sh
talosctl version --help
```
4. Install [Talhelper](https://budimanjojo.github.io/talhelper/latest/)
```bash
curl https://i.jpillora.com/budimanjojo/talhelper! | sudo bash
talhelper -v
```
5. Install [Kubectl](https://kubernetes.io/docs/reference/kubectl/)
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```
6. Install [Sops](https://github.com/getsops/sops)
```bash
curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
chmod +x /usr/local/bin/sops
sops -v
```
7. Install [Age](https://github.com/FiloSottile/age)
```bash
sudo apt install age
age -version
```
8. Install [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli)
```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```
9. Clone my github repository [c0depool-iac](https://github.com/c0depool/c0depool-iac)
```bash
cd $HOME
git clone https://github.com/c0depool/c0depool-iac.git
```

## Create Talos VM template using Packer

1. Generate an API token for Proxmox root user. Login to Proxmox web console using root user. Navigate to Datacenter → Permissions → API Tokens → Add. Select `root` as the user, give a name for the token ID and click Add. Copy the token once displayed.
![alt text](/assets/img/2024-07-07-automating-talos-installation-on-proxmox-with-packer-and-terraform/proxmox-create-token.webp)
2. Open a shell to the Proxmox node. From console select the Proxmox node → Shell.
3. Download [Arch Linux ISO](https://archlinux.org/download/), this is only used to copy Talos raw image.
```bash
cd /var/lib/vz/template/iso
wget https://geo.mirror.pkgbuild.com/iso/2024.06.01/archlinux-2024.06.01-x86_64.iso
```
4. Update the `c0depool-iac/packer/talos-packer/vars/local.pkrvars.hcl` file in the cloned repository with the Proxmox node and Talos details.
5. Run Packer to build the Talos template.
```bash
cd $HOME/c0depool-iac/packer/talos-packer/
packer init -upgrade .
packer validate -var-file="vars/local.pkrvars.hcl" .
packer build -var-file="vars/local.pkrvars.hcl" .
```
After a few minutes, Packer will create a new VM template in Proxmox with ID `9700`. We will use this template to create Talos VMs using Terraform.

## Create Talos VMs using Terraform

1. Create a copy of `c0depool-iac/terraform/c0depool-talos-cluster/example.credentails.auto.tfvars` file as `credentails.auto.tfvars` and update the Proxmox node details.
```bash
cd $HOME/c0depool-iac/terraform/c0depool-talos-cluster/
cp example.credentails.auto.tfvars credentails.auto.tfvars
# Update the file credentails.auto.tfvars
```
2. Open `c0depool-iac/terraform/c0depool-talos-cluster/locals.tf` and add/remove the nodes according to your cluster requirements. By default I have 6 nodes: 3 masters and 3 workers. You should at least have one master and one worker. Here is an example configuration -
```
vm_master_nodes = {
  "0" = {
    vm_id          = 200                                    # VM ID
    node_name      = "talos-master-00"                      # VM hostname
    clone_target   = "talos-v1.7.1-cloud-init-template"     # Target template, the one created by packer
    node_cpu_cores = "2"                                    # CPU
    node_memory    = 2048                                   # Memory
    node_ipconfig  = "ip=192.168.0.170/24,gw=192.168.0.1"   # IP configuration
    node_disk      = "32"                                   # Disk in GB
  }
}
```
3. Run Terraform to provision the servers.
```bash
cd $HOME/c0depool-iac/terraform/c0depool-talos-cluster/
# Initialize Terraform
terraform init
# Plan
terraform plan -out .tfplan
# Apply
terraform apply .tfplan
```
Once the provisioning is completed, Terraform will display the MAC Addresses of the nodes it created. Please note it down as we will be used it later for generating Talos configuration.

## Generating Talos Configuration using Talhelper

1. Update `c0depool-iac/talos/talconfig.yaml` according to your needs, add MAC addresses of the Talos nodes under `hardwareAddr`.
2. Generate Talos secrets.
```bash
cd $HOME/c0depool-iac/talos
talhelper gensecret > talsecret.sops.yaml
```
3. Create Age secret key.
```bash
mkdir -p $HOME/.config/sops/age/
age-keygen -o $HOME/.config/sops/age/keys.txt
```
4. In the `c0depool-iac/talos` directory, create a `.sops.yaml` with below content.
```yaml
---
creation_rules:
  - age: >-
      <age-public-key> ## get this in the keys.txt file from previous step
```
5. Encrypt Talos secrets with Age and Sops.
```bash
cd $HOME/c0depool-iac/talos
sops -e -i talsecret.sops.yaml
```
6. Generate Talos configuration
```bash
cd $HOME/c0depool-iac/talos
talhelper genconfig
```
Configuration for each Talos node will be generated in `clusterconfig` directory.

## Bootsrap Talos

1. Apply the corresponding configuration **for each** of your node from `c0depool-iac/talos/clusterconfig` directory.
```bash
# For master node(s)
cd $HOME/c0depool-iac/talos/
talosctl apply-config --insecure --nodes <master-node ip> --file clusterconfig/<master-config>.yaml
# For worker(s)
talosctl apply-config --insecure --nodes <worker-node ip> --file clusterconfig/<worker-config>.yaml
```
2. Wait for a few minutes for the nodes to reboot. Proceed with bootstrapping Talos.
```bash
cd $HOME/c0depool-iac/talos/
# Copy Talos config to $HOME/.talos/config to avoid using --talosconfig
mkdir -p $HOME/.talos
cp clusterconfig/talosconfig $HOME/.talos/config
# Run the bootstrap command
# Note: The bootstrap operation should only be called ONCE on a SINGLE control plane/master node (use any one if you have multiple master nodes). 
talosctl bootstrap -n <master-node ip>
```
3. Generate kubeconfig and save it to your home directory.
```bash
mkdir -p $HOME/.kube
talosctl -n <master-node ip> kubeconfig $HOME/.kube/config
```
4. Check the status of your nodes. Since we use Cilium for container networking, the nodes might not be in "Ready" state to accept workloads. We can fix it later by installing Cilium.
```bash
kubectl get nodes
```
5. Optional - if you need any custom extensions, upgrade the cluster using the factory image from [factory.talos.dev](https://factory.talos.dev/).
```bash
talosctl upgrade --image factory.talos.dev/installer/<image schematic ID>:<talos version> --preserve --nodes "<list of master and worker nodes, comma separated>"
# Verify extensions for each node
talosctl get extensions --nodes <node IP>
```

## Install Cilium and L2 Load Balancer

[Cilium](https://cilium.io/) is an open source, production ready, cloud native networking solution for Kubernetes. Talos by default uses a lightweight networking plugin called [Flannel](https://github.com/flannel-io/flannel), which works perfectly fine for many. I just wanted to experiment with a production ready and secure networking solution. Additionally, since this is a bare-metal installation, we can make use of Cilium's [L2 aware load balancer](https://docs.cilium.io/en/latest/network/l2-announcements/) to expose the LoadBalancer, as an alternative to [MetalLB](https://metallb.universe.tf/).

1. Install Cilium using the cli
```bash
cilium install \
  --helm-set=ipam.mode=kubernetes \
  --helm-set=kubeProxyReplacement=true \
  --helm-set=securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --helm-set=securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --helm-set=cgroup.autoMount.enabled=false \
  --helm-set=cgroup.hostRoot=/sys/fs/cgroup \
  --helm-set=l2announcements.enabled=true \
  --helm-set=externalIPs.enabled=true \
  --helm-set=devices=eth+
```
2. Verify your cluster. Now the nodes should be in "Ready" state.
```bash
kubectl get nodes
kubectl get pods -A
```
3. Create CiliumLoadBalancerIPPool. For the pool `cidr`, it is mandatory to select a /30 or wider range so that we get at least 2 IPs after reserving the first and last ones. For eg if we use `192.168.0.100/30`, we get 2 IPs `192.168.0.101` and `192.168.0.102`. I am planning to use only one LoadBalancer service for the ingress controller, so this works for me. 
```bash
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata: 
  name: "cilium-lb-pool"
spec:
  blocks:
    - cidr: "192.168.0.100/30"
EOF
```
4. Create CiliumL2AnnouncementPolicy.
```bash
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: "cilium-l2-policy"
spec:
  interfaces:
  - eth0
  externalIPs: true
  loadBalancerIPs: true
EOF
```
5. Install [Ingress Nginx Controller](https://github.com/kubernetes/ingress-nginx) with an annotation to use the Cilium L2 load balancer IP.
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.externalTrafficPolicy="Local" \
  --set controller.kind="DaemonSet" \
  --set controller.service.annotations."io.cilium/lb-ipam-ips"="192.168.0.101"
# Check if the LB service has the EXTERNAL-IP assigned
kubectl get svc ingress-nginx-controller -n ingress-nginx
```
Your ingress-nginx now has an external IP `192.168.0.101` and all your ingress resources will be available via this IP.

## Install Longhorn

Since we have multiple kubernetes nodes, it is essential to have a distributed storage solution. While there are many solutions available like [Rook-Ceph](https://rook.io/), [Mayastor](https://github.com/openebs/Mayastor) etc., I was already using [Longhorn](https://longhorn.io/) with my K3s cluster where I have all my applications backed up. Luckily Longhorn now [supports](https://longhorn.io/docs/1.6.2/advanced-resources/os-distro-specific/talos-linux-support) Talos. In the Talos configuration, I have added an [extraMount](https://github.com/c0depool/c0depool-iac/blob/6416eeb6339b6be2ac0b0634a96a093bd69a6e9d/talos/talconfig.yaml#L130) for the longhorn volume. Let us install Longhorn and use the volume as our disk. 

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --version 1.6.2 \
  --set defaultSettings.defaultDataPath="/var/mnt/longhorn"
```

Congratulations, your Talos k8s cluster is now ready! Start deploying your workloads. ☸️

## Credits and References

- [talos-proxmox-kaas](https://github.com/kubebn/talos-proxmox-kaas/tree/main)
- [mkz.me](https://mkz.me/weblog/posts/cilium-enable-ingress-controller/)
- [AI Image Central](https://aiimagecentral.com/)