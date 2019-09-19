part1  所有节点设置：(两个VM 一个作为master 一个作为node)

一、系统设置

1.1 增加源 

 增加阿里源 

 yum install ntpdate -y
 ntpdate time.windows.com
 yum install wget -y 
 mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak

 wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
 
 新增kubernetes源
 
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

 yum clean all
 yum makecache

1.2 关闭防火墙与selinux

 firewall-cmd --state        
 systemctl stop firewalld.service      
 systemctl disable firewalld.service    

 getenforce  
 setenforce 0    //0代表disabled 
 永久关闭 
 sed -i 's/^ *SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config  
  

1.3修改主机名


修改master节点

hostnamectl set-hostname master


修改node节点
hostnamectl set-hostname node1


1.5 修改hosts文件

cat /etc/hosts
 
10.170.2.150    master
10.170.2.50    node1


1.6 验证mac地址uuid

cat /sys/class/net/ens33/address
cat /sys/class/dmi/id/product_uuid
保证各节点mac和uuid唯一


1.7 禁用swap

1.7.1 临时禁用
 swapoff -a

1.7.2 永久禁用
若需要重启后也生效，在禁用swap后还需修改配置文件/etc/fstab，注释swap

sed -i.bak '/swap/s/^/#/' /etc/fstab


1.8 内核参数修改

1.8.1 临时修改
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1

此处若报错  sysctl: cannot stat /proc/sys/net/bridge/bridge-nf-call-iptables: No such file or directory
解决办法： 
modprobe br_netfilter

1.8.2 永久修改
vim /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1

sysctl -p /etc/sysctl.d/k8s.conf

1.8.3 开启路由转发规则 
echo "1" > /proc/sys/net/ipv4/ip_forward

二、 Docker安装 

2.1. 安装依赖包

 安装指定版本docker（考虑k8s与docker的兼容性） 

 yum install -y yum-utils   device-mapper-persistent-data   lvm2
 yum-config-manager --add-repo  https://download.docker.com/linux/centos/docker-ce.repo
 yum list docker-ce --showduplicates | sort -r
 yum install -y docker-ce-18.09.8 docker-ce-cli-18.09.8 containerd.io
 

 安装最新版本docker
 
 yum install -y docker-ce docker-ce-cli containerd.io


2.2  启动并验证Docker

  systemctl start docker
  systemctl enable docker
  docker --version
  

2.3 修改Cgroup Driver，修改daemon.json

cat > /home/daemon.json << EOF
{"exec-opts": ["native.cgroupdriver=systemd"]}
EOF
 
 
2.4 重新加载docker
  systemctl daemon-reload
  systemctl restart docker


三、安装k8s 


 yum list kubelet --showduplicates | sort -r 

 yum install -y kubelet-1.15.3 kubeadm-1.15.3 kubectl-1.15.3

 systemctl enable kubelet && systemctl start kubelet
 
  docker pull  quay.io/coreos/flannel:v0.11.0-amd64
part2 分节点部署 
一、 master节点初始化（以下操作只需要安装在master节点） 

1.使用kubeadm自动化部署
 
kubeadm init --apiserver-advertise-address="10.170.2.49" --image-repository registry.aliyuncs.com/google_containers --kubernetes-version v1.15.3 --service-cidr=10.1.0.0/16 --pod-network-cidr=10.244.0.0/16
 --kubernetes-version：指定kubeadm版本；
 --pod-network-cidr：指定pod所属网络
 --service-cidr：指定service网段
 --ignore-preflight-errors=Swap/all：忽略 swap/所有 报错（可以加可以不加） 
 
 若此处init成功，则会显示以下信息（下面三行需要操作，最后的kubeadm join命令用于node节点添加） 

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubeadm join 10.170.2.49:6443 --token 22jryz.f1nr942942rprkmf \
    --discovery-token-ca-cert-hash sha256:5d956f70798e03a3712691d9915d4f383546e140e0f4119301da15b9372c0f57

2. 安装flannel网络

 docker pull  quay.io/coreos/flannel:v0.11.0-amd64

 kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

3.查询集群信息
 
查询组件状态信息   kubectl get cs
查询集群节点信息   kubectl get nodes
查询名称空间       kubectl get ns
二、 node节点部署 

加入master集群 
kubeadm join 10.170.2.49:6443 --token 22jryz.f1nr942942rprkmf \
    --discovery-token-ca-cert-hash sha256:5d956f70798e03a3712691d9915d4f383546e140e0f4119301da15b9372c0f57

之后可以使用kubectl get nodes在主机查看是否加入成功
四 部署deployment nginx
kubectl create deployment nginx --image=nginx
kubectl get deployments
删除服务 
kubectl delete deployments/nginx services/nginx

扩容 
kubectl scale deployment nginx --replicas=3
 
 
五  部署访问

5.1 部署Dashboard

docker pull lizhenliang/kubernetes-dashboard-amd64:v1.10.1（每个节点都要下载） 

wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

修改文件 kubernetes-dashboard.yaml

        image: lizhenliang/kubernetes-dashboard-amd64:v1.10.1
     
      spec:
           type: NodePort
           ports:
           - port: 443
           targetPort: 8443
           nodePort: 30001


   kubectl apply -f kubernetes-dashboard.yaml

通过 kubectl get pods -A -o wide  查看其部署在哪个节点之后访问（火狐浏览器） 

访问地址：https://10.170.2.150:30001  

 创建service account并绑定默认cluster-admin管理员集群角色：（注意权限问题） 

 kubectl create serviceaccount dashboard-admin -n kube-system
 
 kubectl create clusterrolebinding system:anonymous   --clusterrole=cluster-admin   --user=system:anonymous
 
 kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin

 kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
 

Data
====
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c
3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkYXNoYm9hcmQtYWRtaW4tdG9rZW4tODVmOXMiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGFzaGJvYXJkLWFkbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYzc5YjBhZDItYTVhYy00YzUyLTkwODYtMWZhOThmM2MyYjg5Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmRhc2hib2FyZC1hZG1pbiJ9.VSP_cFZYu6IDRsxOtx9Xfg4mU8fLQKLe1Sz6OPnPvtU5fp7MncE7vDLuRyUmBWzvqcBuMB1MtMQiDXkyUYQYK53LvnW825laqr_Em2NdLABIBUCOvlgtq3BEAewYoAKZ1PnusfMOGySuCccm78E4Sh17kcmxofKwULyV0puzYY3GL7uFvuZrU3dlKe8wL-zJn_iasX0E_9-ebEBbQLLf6Sm5Ul5Bq5cwd5k9Si1tm1rDTx2k18gjOTXjv6iic9KYIzHAksSjY2vEtmVO_62kHgZhIpEl-lVyLELGN7IFt8MyaBqlGVXVVqOD-XaldyuuLccHjRQV2SVm-SXIn8jGHQca.crt:     1025 bytes




调式所用命令： 


 kubectl get deployment kubernetes-dashboard -n kube-system
 kubectl get pods -n kube-system -o wide
 kubectl get services -n kube-system
 
 netstat -ntlp|grep 30001

 kubectl describe pods kubernetes-dashboard-79ddd5-khq4h  --namespace=kube-system
 kubectl logs kubernetes-dashboard-79ddd5-khq4h  --namespace=kube-system



/*
3.1 镜像下载的脚本
[root@master ~]# more image.sh 

#!/bin/bash
url=registry.cn-hangzhou.aliyuncs.com/google_containers
version=v1.15.3
images=(`kubeadm config images list --kubernetes-version=$version|awk -F '/' '{print $2}'`)
for imagename in ${images[@]} ; do
  docker pull $url/$imagename
  docker tag $url/$imagename k8s.gcr.io/$imagename
  docker rmi -f $url/$imagename
done

3.2 下载镜像
运行脚本image.sh，下载指定版本的镜像

[root@master ~]# ./image.sh
[root@master ~]# docker images
*/

谷歌非密连接 
C:\Users\Administrator\AppData\Local\Google\Chrome\Application\chrome.exe --test-type --ignore-certificate-errors

关机之后需要重新部署的：
master:
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
echo "1" > /proc/sys/net/ipv4/ip_forward
删除之前创建时产生的yaml文件 
kubeadm  reset 
之后重新 kubeadm init即可
node: 
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
echo "1" > /proc/sys/net/ipv4/ip_forward
删除之前创建时产生的yaml文件 
kubeadm  reset 
kubeadm join(基于master)

