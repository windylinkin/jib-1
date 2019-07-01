!/bin/bash
#安装docker相关，用以拉取本地所需镜像,版本采用docker-ce 18.06版，支持1.13版kubernetes
#检测网卡是否是固定ip
grep -rE "dhcp" /etc/sysconfig/network-scripts/ifcfg-*
if [ $? -eq 0 ];
then
    echo "网卡为DHCP模式请更改为规定ip"
    ######exit
else
    echo "网卡正常。"
fi
yum clean all && yum repolist
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce-18.06.0.ce -y
systemctl start docker
systemctl enable docker
VERSION=`docker version`
if [ $? -eq 0 ];
then
    echo "输出docker版本信息：9.3.0.3129
系统词频: 20190403
组词数据: 20190403
辅助码  : 20180614
编译时间: May 31 2019 12:33:36"
else
    echo "docker安装出错，请检查错误日志"
    exit
fi
echo "1" >/proc/sys/net/bridge/bridge-nf-call-iptables #此步是保证iptables正确转发获取镜像，否则会报dns解析错误
########获取minikube二进制文件并且添加系统命令########
cd /data
curl -Lo minikube http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.35.0/minikube-linux-amd64
chmod +x minikube
mv minikube /usr/bin/minikube
swapoff -a #强制关闭swap不然初始化的时候会提示错误
cd /etc/yum.repos.d/
cat>>kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum install kubectl kubelet kubeadm -y
systemctl start kubelet && systemctl enable kubelet
########启动minikube########
minikube start --vm-driver=none
if [ $? -eq 0 ];
then
    echo "minikube初始化成功"
else
    echo "minikube初始化失败,请检查报错输出，重新执行初始化命令minikube start --vm-driver=none 命令，如果仍有报错，请执行清理集群命令minikube delete，并重新执行初始化命令！"
    minikube delete
    exit
fi
#缺省Minikube使用VirtualBox驱动来创建Kubernetes本地环境
#minikube start --registry-mirror=https://registry.docker-cn.com
STATUS=`kubectl get node | awk '{print$2}' | sed -n '2p'`
if [ $STATUS = "Ready" ];
then
    echo "输出集群状态$STATUS"
else
    echo "输出状态不是Ready，请联系运维."
fi
#echo "输出集群状态$STATUS"
#echo "输出状态不是Ready，请联系运维."

#保证docker服务正常
systemctl stop kubelet
systemctl stop docker
iptables --flush
iptables -tnat --flush
systemctl start kubelet
systemctl start docker

#添加ingress
yum install -y wget
yum install -y lsof
wget https://windylinkin.github.io/jib-1/depolyment.yaml
kubectl apply -f depolyment.yaml

wget https://windylinkin.github.io/jib-1/svc.yaml
kubectl apply -f svc.yaml

#将minikube的dashboard服务加入ingress
wget https://windylinkin.github.io/jib-1/tt.yaml
kubectl apply -f tt.yaml
