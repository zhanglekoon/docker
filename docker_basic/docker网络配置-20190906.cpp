docker ��������

�˽׶�Ŀ��: ����������host����ͬ����  �໥����ping

��ʱ��������ģʽ��
hostͨ��NAT��centos VM����������VM��������  ��������ens33 

����1������pipework������ʵ��

��һ�����linux����br1
0����װ���ŵ�����

yum -y install tunctl bridge-utils
1���������������ļ�

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-br1
TYPE=Bridge
DEVICE=br1
BOOTPROTO=static
DEFROUTE=yes
NAME=br1
ONBOOT=yes

EOF
2���޸�ԭ�����������ļ�(�ҽ�em4��br1)

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-em4
TYPE=Ethernet
DEVICE=em4
ONBOOT=yes
BRIDGE=br1          
EOF
3�����þ�̬IP��ַ

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
4����������

service network restart
5�����ŵ���ʾ

brctl show

�ڶ���������docker ��������br1
 
vim /usr/lib/systemd/system/docker.service
��������Ļ������� 
EnvironmentFile=-/etc/default/docker
ExecStart=/usr/bin/dockerd -H fd:// $DOCKER_OPTS  --containerd=/run/containerd/containerd.sock

��docker�����ļ����޸�
/etc/default/docker
DOCKER_OPTS="-b=br1"

DOCKER_OPTS="--dns 159.226.39.1"

#����

systemctl daemon-reload
systemctl restart docker
systemctl status docker 

��ʱ����������Ϊhost(NAT��br1)---centos(br1)---container 
container����ͨ��br1����centos ֮��������ͬһ��������
 
 ʵ�������� 
 docker run -it --privileged 
-v /sys/bus/pci/drivers:/sys/bus/pci/drivers  
-v /sys/kernel/mm/hugepages:/sys/kernel/mm/hugepages 
-v /sys/devices/system/node:/sys/devices/system/node
 -v /dev:/dev 
  -v /lib/modules:/lib/modules 
  -v /opt:/opt
--net=none --name=test  centos7.4  bash  

 ����pipework����IP
 pipework br1 test -i ens34 10.170.2.213/24@10.170.2.254 (IP@����)

pipework��װ��
# wget https://github.com/jpetazzo/pipework/archive/master.zip
# unzip pipework-master.zip
# cp pipework-master/pipework? /usr/local/bin/
# chmod +x /usr/local/bin/pipework

 ��ʱ������hostֱ��pingͨ 10.170.2.213 �����������test�� 
 
 ��������macvlan 
 macvlan��ԭ��������������������������������������ͨ����ͬ��MAC��ַ��������·�������������ת���ģ����ǱȽ��µ��������⻯��������Ҫ���µ��ں�֧�֣�Linux kernel v3.9�C3.19 and 4.0+��
 �����½�һ���Ž�ģʽ����������ens38 
 
 docker network create -d macvlan --subnet 10.170.2.0/24 --gateway 10.170.2.254 -o parent=ens38  mynet
 /*
 -d macvlan  ����kernel��ģ����
--subnet ��������������
--gateway ������������������
-o parent �̳�ָ�����ε�����
*/
 docker run --net=mynet --ip=10.170.2.158  -it --rm centos7.4  /bin/bash
 
 ��ʱҲ������host pingͨIPΪ 10.170.2.158������ 
