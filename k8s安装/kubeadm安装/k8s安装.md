# 环境准备

## 关闭防火墙

```
systemctl stop firewalld
systemctl disable firewalld
```
## 关闭selinux

```
sed -i 's/enforcing/disabled/' /etc/selinux/config 
setenforce 0
```

## 关闭swap

### 第一步关闭swap分区

`swapoff /mnt/swap`

### 第二步修改配置文件 - /etc/fstab

删除 /mnt/swap swap swap defaults 0 0 这一行或者注释掉这一行

### 第三步确认swap已经关闭

`free -m`

若都显示 0 则表示关闭成功

### 第四步调整 swappiness 参数

`echo 0 > /proc/sys/vm/swappiness   # 临时生效`

```
vim /etc/sysctl.conf                           # 永久生效
#  修改 vm.swappiness 的修改为 0
vm.swappiness=0
sysctl -p                                            # 使配置生效
```

### 修改主机名

`hostnamectl set-hostname k8s-node-1`

### 查看主机名

`hostname`

### 添加主机名与IP对应关系（记得设置主机名）

```
$ cat /etc/hosts
192.168.31.61 k8s-master
192.168.31.62 k8s-node1
192.168.31.63 k8s-node2
```

### 将桥接的IPv4流量传递到iptables的链

```
$ cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
$ sysctl --system
```

# 所有节点安装Docker/kubeadm/kubelet

## 安装Docker

```
$ wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
$ yum -y install docker-ce-18.06.1.ce-3.el7
$ systemctl enable docker && systemctl start docker
$ docker --version
Docker version 18.06.1-ce, build e68fc7a
```

## 添加阿里云YUM软件源

```
$ cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

## 安装kubeadm，kubelet和kubectl

```
$ yum install -y kubelet-1.15.0 kubeadm-1.15.0 kubectl-1.15.0
$ systemctl enable kubelet
```

# 部署Kubernetes Master

```
$ kubeadm init \
--apiserver-advertise-address=192.168.231.134 \
--image-repository registry.aliyuncs.com/google_containers \
--kubernetes-version v1.15.0 \
--service-cidr=10.1.0.0/16 \
--pod-network-cidr=10.244.0.0/16
```

由于默认拉取镜像地址k8s.gcr.io国内无法访问，这里指定阿里云镜像仓库地址。

使用kubectl工具：

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
$ kubectl get nodes
```

# 安装Pod网络插件（CNI）

```
$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
```

# 加入Kubernetes Node
向集群添加新节点，执行在kubeadm init输出的kubeadm join命令：

```
$ kubeadm join 192.168.31.61:6443 --token esce21.q6hetwm8si29qxwn \
  --discovery-token-ca-cert-hash sha256:00603a05805807501d7181c3d60b478788408cfe6cedefedb1f97569708be9c5
```

注意：如果token过期，首先重新生成token：
### 1、重新生成token，例如：aa78f6.8b4cafc8ed26c34f

```
$ [root@walker-1 kubernetes]# kubeadm token create
[kubeadm] WARNING: starting in 1.8, tokens expire after 24 hours by default (if you require a non-expiring token use --ttl 0)
aa78f6.8b4cafc8ed26c34f
[root@walker-1 kubernetes]# kubeadm token list
TOKEN                     TTL       EXPIRES                     USAGES                   DESCRIPTION   EXTRA GROUPS
aa78f6.8b4cafc8ed26c34f   23h       2017-12-26T16:36:29+08:00   authentication,signing   <none>        system:bootstrappers:kubeadm:default-node-token
```

### 2、获取ca证书的sha256编码hash值：

```
$[root@walker-1 kubernetes]# openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
0fd95a9bc67a7bf0ef42da968a0d55d92e52898ec37c971bd77ee501d845b538
```

### 3、节点加入集群

```
$ kubeadm join 192.168.121.130:6443 --token aa78f6.8b4cafc8ed26c34f \
    --discovery-token-ca-cert-hash sha256:0fd95a9bc67a7bf0ef42da968a0d55d92e52898ec37c971bd77ee501d845b538
```

# Rancher 安装

```
docker run -d --restart=unless-stopped \
-p 8080:80 -p 8443:443 \
-v  /var/lib/rancher:/var/lib/rancher/ \
-v /root/var/log/auditlog:/var/log/auditlog \
-e AUDIT_LEVEL=3 \
rancher/rancher:stable
```
