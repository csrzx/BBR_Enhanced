#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
clear


[[ "`id -u`" != "0" ]] && echo -e "请以root权限运行此脚本！" && exit 1

[[ -z "`cat /etc/issue | grep -i "debian"`" ]] && echo -e "此脚本仅支持Debian，操作终止。" && exit 1

install(){
	github="https://raw.githubusercontent.com/csrzx/BBR_Enhanced/main"
	Distribution=`cat /etc/apt/sources.list | grep -v "cdrom" | grep -v "#" | sed '/^$/d' | awk '{print $3}' | awk -F '-' '{print $1}' | head -n 1`
	current_kernel_version=`uname -a | awk '{print $3}' | awk -F '-' '{print $1}'`
	if [[ -z `wget -qO- ${github}/supported_kernel_list.txt | grep "${current_kernel_version}"` ]]; then
	    echo -e "当前内核版本：${current_kernel_version} 不在支持范围，操作终止。"
	    exit 1
	fi

	apt -y install build-essential
	[[ "`echo $?`" != "0" ]] && echo "build-essential 安装失败，请重试。" && exit 1
	apt -y install linux-headers-$(uname -r)
	[[ "`echo $?`" != "0" ]] && echo "linux-headers-$(uname -r) 安装失败，请重试。" && exit 1

	[[ ! -d /home/bbr_enhanced ]] && mkdir -p /home/bbr_enhanced
	cd /home/bbr_enhanced
	rm -rf /home/bbr_enhanced/*

	wget ${github}/bbr/${current_kernel_version}/tcp_bbrenhanced.c > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		echo "tcp_bbrenhanced.c文件下载失败，请重试。" && exit 1
	fi
	wget ${github}/Makefile > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		echo "Makefile文件下载失败，请重试。" && exit 1
	fi
	wget ${github}/sources.list/${Distribution} > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		echo "sources.list文件下载失败，请重试。" && exit 1
	fi

	if [[ -n "`cat ./${Distribution} | grep "${Distribution}"`" ]]; then
		cp /etc/apt/sources.list /etc/apt/sources.list.bak && cp ./${Distribution} /etc/apt/sources.list
		apt update &> /dev/null
	fi

	make && make install

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

echo -e "BBR 增强版\n"
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