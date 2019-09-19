part1  ���нڵ����ã�(����VM һ����Ϊmaster һ����Ϊnode)

һ��ϵͳ����

1.1 ����Դ 

 ���Ӱ���Դ 

 yum install ntpdate -y
 ntpdate time.windows.com
 yum install wget -y 
 mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak

 wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
 
 ����kubernetesԴ
 
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

1.2 �رշ���ǽ��selinux

 firewall-cmd --state        
 systemctl stop firewalld.service      
 systemctl disable firewalld.service    

 getenforce  
 setenforce 0    //0����disabled 
 ���ùر� 
 sed -i 's/^ *SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config  
  

1.3�޸�������


�޸�master�ڵ�

hostnamectl set-hostname master


�޸�node�ڵ�
hostnamectl set-hostname node1


1.5 �޸�hosts�ļ�

cat /etc/hosts
 
10.170.2.150    master
10.170.2.50    node1


1.6 ��֤mac��ַuuid

cat /sys/class/net/ens33/address
cat /sys/class/dmi/id/product_uuid
��֤���ڵ�mac��uuidΨһ


1.7 ����swap

1.7.1 ��ʱ����
 swapoff -a

1.7.2 ���ý���
����Ҫ������Ҳ��Ч���ڽ���swap�����޸������ļ�/etc/fstab��ע��swap

sed -i.bak '/swap/s/^/#/' /etc/fstab


1.8 �ں˲����޸�

1.8.1 ��ʱ�޸�
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1

�˴�������  sysctl: cannot stat /proc/sys/net/bridge/bridge-nf-call-iptables: No such file or directory
����취�� 
modprobe br_netfilter

1.8.2 �����޸�
vim /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1

sysctl -p /etc/sysctl.d/k8s.conf

1.8.3 ����·��ת������ 
echo "1" > /proc/sys/net/ipv4/ip_forward

���� Docker��װ 

2.1. ��װ������

 ��װָ���汾docker������k8s��docker�ļ����ԣ� 

 yum install -y yum-utils   device-mapper-persistent-data   lvm2
 yum-config-manager --add-repo  https://download.docker.com/linux/centos/docker-ce.repo
 yum list docker-ce --showduplicates | sort -r
 yum install -y docker-ce-18.09.8 docker-ce-cli-18.09.8 containerd.io
 

 ��װ���°汾docker
 
 yum install -y docker-ce docker-ce-cli containerd.io


2.2  ��������֤Docker

  systemctl start docker
  systemctl enable docker
  docker --version
  

2.3 �޸�Cgroup Driver���޸�daemon.json

cat > /home/daemon.json << EOF
{"exec-opts": ["native.cgroupdriver=systemd"]}
EOF
 
 
2.4 ���¼���docker
  systemctl daemon-reload
  systemctl restart docker


������װk8s 


 yum list kubelet --showduplicates | sort -r 

 yum install -y kubelet-1.15.3 kubeadm-1.15.3 kubectl-1.15.3

 systemctl enable kubelet && systemctl start kubelet
 
  docker pull  quay.io/coreos/flannel:v0.11.0-amd64
part2 �ֽڵ㲿�� 
һ�� master�ڵ��ʼ�������²���ֻ��Ҫ��װ��master�ڵ㣩 

1.ʹ��kubeadm�Զ�������
 
kubeadm init --apiserver-advertise-address="10.170.2.49" --image-repository registry.aliyuncs.com/google_containers --kubernetes-version v1.15.3 --service-cidr=10.1.0.0/16 --pod-network-cidr=10.244.0.0/16
 --kubernetes-version��ָ��kubeadm�汾��
 --pod-network-cidr��ָ��pod��������
 --service-cidr��ָ��service����
 --ignore-preflight-errors=Swap/all������ swap/���� �������Լӿ��Բ��ӣ� 
 
 ���˴�init�ɹ��������ʾ������Ϣ������������Ҫ����������kubeadm join��������node�ڵ���ӣ� 

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubeadm join 10.170.2.49:6443 --token 22jryz.f1nr942942rprkmf \
    --discovery-token-ca-cert-hash sha256:5d956f70798e03a3712691d9915d4f383546e140e0f4119301da15b9372c0f57

2. ��װflannel����

 docker pull  quay.io/coreos/flannel:v0.11.0-amd64

 kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

3.��ѯ��Ⱥ��Ϣ
 
��ѯ���״̬��Ϣ   kubectl get cs
��ѯ��Ⱥ�ڵ���Ϣ   kubectl get nodes
��ѯ���ƿռ�       kubectl get ns
���� node�ڵ㲿�� 

����master��Ⱥ 
kubeadm join 10.170.2.49:6443 --token 22jryz.f1nr942942rprkmf \
    --discovery-token-ca-cert-hash sha256:5d956f70798e03a3712691d9915d4f383546e140e0f4119301da15b9372c0f57

֮�����ʹ��kubectl get nodes�������鿴�Ƿ����ɹ�
�� ����deployment nginx
kubectl create deployment nginx --image=nginx
kubectl get deployments
ɾ������ 
kubectl delete deployments/nginx services/nginx

���� 
kubectl scale deployment nginx --replicas=3
 
 
��  �������

5.1 ����Dashboard

docker pull lizhenliang/kubernetes-dashboard-amd64:v1.10.1��ÿ���ڵ㶼Ҫ���أ� 

wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

�޸��ļ� kubernetes-dashboard.yaml

        image: lizhenliang/kubernetes-dashboard-amd64:v1.10.1
     
      spec:
           type: NodePort
           ports:
           - port: 443
           targetPort: 8443
           nodePort: 30001


   kubectl apply -f kubernetes-dashboard.yaml

ͨ�� kubectl get pods -A -o wide  �鿴�䲿�����ĸ��ڵ�֮����ʣ����������� 

���ʵ�ַ��https://10.170.2.150:30001  

 ����service account����Ĭ��cluster-admin����Ա��Ⱥ��ɫ����ע��Ȩ�����⣩ 

 kubectl create serviceaccount dashboard-admin -n kube-system
 
 kubectl create clusterrolebinding system:anonymous   --clusterrole=cluster-admin   --user=system:anonymous
 
 kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin

 kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
 

Data
====
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c
3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkYXNoYm9hcmQtYWRtaW4tdG9rZW4tODVmOXMiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGFzaGJvYXJkLWFkbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYzc5YjBhZDItYTVhYy00YzUyLTkwODYtMWZhOThmM2MyYjg5Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmRhc2hib2FyZC1hZG1pbiJ9.VSP_cFZYu6IDRsxOtx9Xfg4mU8fLQKLe1Sz6OPnPvtU5fp7MncE7vDLuRyUmBWzvqcBuMB1MtMQiDXkyUYQYK53LvnW825laqr_Em2NdLABIBUCOvlgtq3BEAewYoAKZ1PnusfMOGySuCccm78E4Sh17kcmxofKwULyV0puzYY3GL7uFvuZrU3dlKe8wL-zJn_iasX0E_9-ebEBbQLLf6Sm5Ul5Bq5cwd5k9Si1tm1rDTx2k18gjOTXjv6iic9KYIzHAksSjY2vEtmVO_62kHgZhIpEl-lVyLELGN7IFt8MyaBqlGVXVVqOD-XaldyuuLccHjRQV2SVm-SXIn8jGHQca.crt:     1025 bytes




��ʽ������� 


 kubectl get deployment kubernetes-dashboard -n kube-system
 kubectl get pods -n kube-system -o wide
 kubectl get services -n kube-system
 
 netstat -ntlp|grep 30001

 kubectl describe pods kubernetes-dashboard-79ddd5-khq4h  --namespace=kube-system
 kubectl logs kubernetes-dashboard-79ddd5-khq4h  --namespace=kube-system



/*
3.1 �������صĽű�
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

3.2 ���ؾ���
���нű�image.sh������ָ���汾�ľ���

[root@master ~]# ./image.sh
[root@master ~]# docker images
*/

�ȸ�������� 
C:\Users\Administrator\AppData\Local\Google\Chrome\Application\chrome.exe --test-type --ignore-certificate-errors

�ػ�֮����Ҫ���²���ģ�
master:
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
echo "1" > /proc/sys/net/ipv4/ip_forward
ɾ��֮ǰ����ʱ������yaml�ļ� 
kubeadm  reset 
֮������ kubeadm init����
node: 
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
echo "1" > /proc/sys/net/ipv4/ip_forward
ɾ��֮ǰ����ʱ������yaml�ļ� 
kubeadm  reset 
kubeadm join(����master)

