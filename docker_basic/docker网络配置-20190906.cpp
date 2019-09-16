docker 网络配置

此阶段目的: 容器网段与host在相同网段  相互可以ping

此时已有网络模式：
host通过NAT与centos VM相连，用于VM连接外网  虚拟网卡ens33 

方案1：利用pipework和网桥实现

第一步：搭建linux网桥br1
0、安装网桥的依赖

yum -y install tunctl bridge-utils
1、创建网桥配置文件

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-br1
TYPE=Bridge
DEVICE=br1
BOOTPROTO=static
DEFROUTE=yes
NAME=br1
ONBOOT=yes

EOF
2、修改原有网卡配置文件(挂接em4到br1)

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-em4
TYPE=Ethernet
DEVICE=em4
ONBOOT=yes
BRIDGE=br1          
EOF
3、配置静态IP地址

cat <<EOF >> /etc/sysconfig/network-scripts/ifcfg-br1
TYPE="Bridge"
DEVICE=br1
BOOTPROTO=static
DEFROUTE=yes
NAME=br1
ONBOOT=yes
IPADDR=10.170.2.150
NETMASK=255.255.255.0
GATEWAY=10.170.2.254
EOF
4、重启网络

service network restart
5、网桥的显示

brctl show

第二步：配置docker 挂载网桥br1
 
vim /usr/lib/systemd/system/docker.service
增加下面的环境变量 
EnvironmentFile=-/etc/default/docker
ExecStart=/usr/bin/dockerd -H fd:// $DOCKER_OPTS  --containerd=/run/containerd/containerd.sock

在docker配置文件中修改
/etc/default/docker
DOCKER_OPTS="-b=br1"

DOCKER_OPTS="--dns 159.226.39.1"

#重载

systemctl daemon-reload
systemctl restart docker
systemctl status docker 

此时，整个网络为host(NAT、br1)---centos(br1)---container 
container可以通过br1连接centos 之后便组成了同一个局域网
 
 实例化容器 
 docker run -it --privileged 
-v /sys/bus/pci/drivers:/sys/bus/pci/drivers  
-v /sys/kernel/mm/hugepages:/sys/kernel/mm/hugepages 
-v /sys/devices/system/node:/sys/devices/system/node
 -v /dev:/dev 
  -v /lib/modules:/lib/modules 
  -v /opt:/opt
--net=none --name=test  centos7.4  bash  

 利用pipework设置IP
 pipework br1 test -i ens34 10.170.2.213/24@10.170.2.254 (IP@网关)

pipework安装：
# wget https://github.com/jpetazzo/pipework/archive/master.zip
# unzip pipework-master.zip
# cp pipework-master/pipework? /usr/local/bin/
# chmod +x /usr/local/bin/pipework

 此时可以在host直接ping通 10.170.2.213 这个容器（即test） 
 
 方法二：macvlan 
 macvlan的原理是在宿主机物理网卡上虚拟出多个子网卡，通过不同的MAC地址在数据链路层进行网络数据转发的，它是比较新的网络虚拟化技术，需要较新的内核支持（Linux kernel v3.9–3.19 and 4.0+）
 首先新建一张桥接模式的虚拟网卡ens38 
 
 docker network create -d macvlan --subnet 10.170.2.0/24 --gateway 10.170.2.254 -o parent=ens38  mynet
 /*
 -d macvlan  加载kernel的模块名
--subnet 宿主机所在网段
--gateway 宿主机所在网段网关
-o parent 继承指定网段的网卡
*/
 docker run --net=mynet --ip=10.170.2.158  -it --rm centos7.4  /bin/bash
 
 此时也可以在host ping通IP为 10.170.2.158的容器 
