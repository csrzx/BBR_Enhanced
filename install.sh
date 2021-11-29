#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
clear


# 检查root权限
[[ "`id -u`" != "0" ]] && echo -e "请以root权限运行此脚本！" && exit 1

# 判断是否为Debian
[[ -z "`cat /etc/issue | grep -i "debian"`" ]] && echo -e "此脚本仅支持Debian，操作终止。" && exit 1

install(){
	# 检查内核版本号
	github="https://raw.githubusercontent.com/csrzx/BBR_Enhanced/main"
	Distribution=`cat /etc/apt/sources.list | grep -v "cdrom" | grep -v "#" | sed '/^$/d' | awk '{print $3}' | awk -F '-' '{print $1}' | head -n 1`
	current_kernel_version=`uname -a | awk '{print $3}' | awk -F '-' '{print $1}'`
	if [[ -z `wget -qO- ${github}/supported_kernel_list.txt | grep "${current_kernel_version}"` ]]; then
	    echo -e "当前内核版本：${current_kernel_version} 不在支持范围，操作终止。"
	    exit 1
	fi

	# 创建临时目录
	[[ ! -d /home/bbr_enhanced ]] && mkdir -p /home/bbr_enhanced && cd /home/bbr_enhanced

	# 下载需要的文件
	wget ${github}/bbr/${current_kernel_version}/tcp_bbrenhanced.c > /dev/null 2>&1
	wget ${github}/Makefile > /dev/null 2>&1
	wget ${github}/sources.list/${Distribution} > /dev/null 2>&1
	[[ ! -f tcp_bbrenhanced.c ]] && echo -e "下载失败，请重试！" && exit 1
	[[ ! -f Makefile ]] && echo -e "下载失败，请重试！" && exit 1
	[[ ! -f ${Distribution} ]] && echo -e "下载失败，请重试！" && exit 1

	# 替换sources.list
	if [[ -n "`cat ./${Distribution} | grep "${Distribution}"`" ]]; then
		cp /etc/apt/sources.list /etc/apt/sources.list.bak && cp ./${Distribution} /etc/apt/sources.list
		apt update &> /dev/null
	fi

	# 安装编译工具及头文件
	apt -y install build-essential linux-headers-$(uname -r)

	# 编译安装BBR增强版
	make && make install

	# 启用BBR魔改版并检查状态
	sed -i '/net\.core\.default_qdisc/d' /etc/sysctl.conf
	sed -i '/net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
	echo -e "\nnet.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo -e "net.ipv4.tcp_congestion_control=bbrenhanced" >> /etc/sysctl.conf
	sysctl -p
	if [[ "`lsmod | grep bbrenhanced`" != "" ]]; then
		echo -e "模块已安装，\c"
		if [[ "`sysctl net.ipv4.tcp_congestion_control | awk '{print $3}'`" = "bbrenhanced" ]]; then
			echo -e "且已启用！\n"
			cd ~ && rm -rf /home/bbr_enhanced
		else echo -e "但未启用！\n"
		fi
	else
		echo -e "模块未安装！\n"
	fi
}

uninstall(){
	sed -i '/net\.core\.default_qdisc/d' /etc/sysctl.conf
	sed -i '/net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
	sysctl -p
	rm /lib/modules/`uname -r`/kernel/net/ipv4/tcp_bbrenhanced.ko
	echo -e "卸载完成。"
}

echo -e "BBR Enhanced for Debian\n"
echo -e "1.安装\n2.卸载\n"
read -p ":" choose
while [[ ! "${choose}" =~ ^[1-2]$ ]]
	do
		read -p "请输入 1 或 2:" choose
	done
if [[ "${choose}" == "1" ]]; then
	install
elif [[ "${choose}" == "2" ]]; then
	uninstall
fi