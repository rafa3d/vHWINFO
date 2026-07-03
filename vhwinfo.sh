#!/bin/bash
###############################################################################################
# vHWINFO - Get information about your virtual (or non) server                                #
# vHWINFO 2.0 Jul 2026                                                                        #
# Author: Rafa Marruedo                                                                       #
###############################################################################################
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY. YOU USE AT YOUR OWN RISK.

clear 2>/dev/null

echo "          ____                                                   ";
echo "    _____/\   \            __  ___       _______   ____________  ";
echo "   /\   /  \___\    _   _ / / / / |     / /  _/ | / / ____/ __ \ ";
echo "  /  \  \  /   /   | | / / /_/ /| | /| / // //  |/ / /_  / / / / ";
echo " /    \  \/___/ \  | |/ / __  / | |/ |/ // // /|  / __/ / /_/ /  ";
echo "/      \_________\ |___/_/ /_/  |__/|__/___/_/ |_/_/    \____/   ";
echo "\      /         / vHWINFO 2.0 Jul 2026                          ";
echo " ";

# --------------------- HOSTNAME & IP ---------------------
host=$(hostname)
domain=$(dnsdomainname 2>/dev/null)

if [[ "$host" != *.* && -n "$domain" ]]; then
    full_host="$host.$domain"
else
    full_host="$host"
fi

public_ip=$(curl -s -4 --max-time 5 https://api.ipify.org 2>/dev/null)
if [[ -n "$public_ip" ]]; then
    echo -e " hostname:\t $full_host (public ip $public_ip)"
else
    echo -e " hostname:\t $full_host"
fi

# --------------------- MAC ---------------------
if hash sw_vers 2>/dev/null; then

    virtual="It is not virtual, is dedicated"

    echo -e " SO:\t\t $(sw_vers -productName) $(sw_vers -productVersion) (build $(sw_vers -buildVersion))"

    kernel_version=$(system_profiler SPSoftwareDataType 2>/dev/null | grep 'Kernel Version:')
    echo -e " kernel:\t ${kernel_version:22}"
    echo -e " virtual:\t $virtual"

    cpu=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    echo -e " CPU:\t\t $cpu"
    
    cores=$(sysctl -n hw.ncpu 2>/dev/null)
    if [[ $cores -gt 1 ]]; then
        echo -e " vcpu:\t\t $cores cores"
    else
        echo -e " vcpu:\t\t $cores core"
    fi

    ram=$(sysctl -n hw.memsize 2>/dev/null)
    ram=$((ram / 1024 / 1024))
    
    # Cálculo de RAM usada en Mac
    free_pages=$(vm_stat | grep 'Pages free:' | awk '{print $3}' | tr -d '.')
    free_mb=$((free_pages * 4096 / 1024 / 1024))
    if [[ $ram -gt 0 ]]; then
        used=$((100 - (free_mb * 100 / ram)))
    else
        used=0
    fi
    echo -e " RAM:\t\t $ram MB ($used% used)"

    hd=$(diskutil info /dev/disk0 2>/dev/null | grep 'Total Size:' | awk -F':' '{print $2}' | awk '{print $1}')
    echo -e " HD:\t\t $hd GB"

    # Velocidad de red usando curl
    speed_bps=$(curl -s -o /dev/null -w '%{speed_download}' http://cachefly.cachefly.net/1mb.test 2>/dev/null)
    if [[ -n "$speed_bps" ]]; then
        speed_mbps=$(awk "BEGIN {print $speed_bps / 1024 / 1024}")
        printf " cachefly 1MB:\t %.1f MB/s\n" "$speed_mbps"
    else
        echo -e " cachefly 1MB:\t (Test failed)"
    fi

# --------------------- LINUX ---------------------
else

    virtual="It is not virtual, is dedicated"
    kernel_version=$(uname -r)
    machine_type=$(uname -m)
    
    if [[ "$machine_type" == 'x86_64' ]]; then
        bits="64 bits"
    else
        bits="32 bits"
    fi

    # Detección moderna de SO
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        so="$PRETTY_NAME"
    elif hash lsb_release 2>/dev/null; then
        so=$(lsb_release -d 2>/dev/null | cut -f2)
    else
        so=$(cat /etc/issue 2>/dev/null)
        # Mapeo manual de versiones antiguas de Debian si no hay os-release
        case "$so" in
            *Debian*6*) so="Debian 6 (squeeze)" ;;
            *Debian*7*) so="Debian 7 (wheezy)" ;;
            *Debian*8*) so="Debian 8 (jessie)" ;;
            *Debian*9*) so="Debian 9 (stretch)" ;;
            *Debian*10*) so="Debian 10 (buster)" ;;
            *Debian*11*) so="Debian 11 (bullseye)" ;;
            *Debian*12*) so="Debian 12 (bookworm)" ;;
            *Debian*13*) so="Debian 13 (trixie)" ;;
            *Proxmox*) so="Debian (Proxmox VE)" ;;
        esac
    fi
    echo -e " SO:\t\t $so $bits"
    echo -e " kernel:\t $kernel_version"

    # Detección de virtualización mejorada
    if hash systemd-detect-virt 2>/dev/null; then
        virt=$(systemd-detect-virt)
        if [[ -n "$virt" && "$virt" != "none" ]]; then
            virtual="$virt"
        fi
    else
        if [[ -d /proc/xen ]]; then virtual="Xen"; fi
        if [[ -f /proc/user_beancounters ]]; then virtual="OpenVZ"; fi
        if grep -qa "kvm-clock" /proc/cpuinfo 2>/dev/null; then virtual="KVM"; fi

        # Detección por DMI (más fiable en servidores físicos y VMs modernas)
        if [[ -r /sys/class/dmi/id/product_name ]]; then
            product=$(cat /sys/class/dmi/id/product_name)
            case "$product" in
                *VMware*) virtual="VMware" ;;
                *VirtualBox*) virtual="VirtualBox" ;;
                *KVM*) virtual="KVM" ;;
                *Microsoft*Virtual*) virtual="Microsoft VirtualPC" ;;
                *Xen*) virtual="Xen" ;;
            esac
        fi

        # Fallback a dmesg si se puede leer
        dmesg_out=$(dmesg 2>/dev/null)
        if [[ -n "$dmesg_out" ]]; then
            if [[ "$dmesg_out" == *"VMware Virtual Platform"* ]]; then virtual="VMware"; fi
            if [[ "$dmesg_out" == *"Parallels Software International"* ]]; then virtual="Parallels"; fi
            if [[ "$dmesg_out" == *"VirtualBox"* ]]; then virtual="VirtualBox"; fi
            if [[ "$dmesg_out" == *"Microsoft VirtualPC"* ]]; then virtual="Microsoft VirtualPC"; fi
        fi
    fi
    echo -e " virtual:\t $virtual"

    # CPU Info
    cpu=$(grep -m1 "model name" /proc/cpuinfo | cut -d':' -f2 | sed 's/^[ \t]*//')
    bogo=$(grep -m1 "bogomips" /proc/cpuinfo | cut -d':' -f2 | sed 's/^[ \t]*//')
    cores=$(grep -c processor /proc/cpuinfo)
    
    if [[ $cores -gt 1 ]]; then
        label="cores"
    else
        label="core"
    fi

    echo -e " cpu:\t\t $cpu"
    echo -e " vcpu:\t\t $cores $label / $bogo bogomips"

    # RAM y Swap
    ram=$(free -m | awk '/Mem:/ {print $2}')
    busy=$(free -m | awk '/Mem:/ {print $3}')
    swap=$(free -m | awk '/Swap:/ {print $2}')
    busy_swap=$(free -m | awk '/Swap:/ {print $3}')

    if [[ $ram -gt 0 ]]; then busy=$((busy * 100 / ram)); else busy=0; fi
    if [[ $swap -gt 0 ]]; then busy_swap=$((busy_swap * 100 / swap)); else busy_swap=0; fi

    label1=""; label2=""
    if [[ $busy -gt 90 ]]; then
        label1="\e[41m"; label2="\e[0m"
    elif [[ $busy -gt 75 ]]; then
        label1="\e[43m"; label2="\e[0m"
    fi

    echo -e " RAM:\t\t $ram MB ($label1$busy% used$label2) / swap $swap MB ($busy_swap% used)"

    # Disco Duro
    total=$(df -h --total 2>/dev/null | grep 'total' | awk '{print $2}')
    used=$(df -h --total 2>/dev/null | grep 'total' | awk '{print $5}')
    used="${used//%}"

    label1=""; label2=""
    if [[ -n "$used" ]]; then
        if [[ $used -gt 90 ]]; then
            label1="\e[41m"; label2="\e[0m"
        elif [[ $used -gt 75 ]]; then
            label1="\e[43m"; label2="\e[0m"
        fi
    fi

    # Test de velocidad de disco
    hdspeed=$(dd if=/dev/zero of=/tmp/ddfile_vhwinfo bs=16k count=12190 2>&1 | grep -o '[0-9.]\+ [GMk]B/s')
    sync
    rm -f /tmp/ddfile_vhwinfo

    if [[ -n "$used" && $used -gt 0 ]]; then
        echo -e " HD:\t\t $total ($label1$used% used$label2) / inkling speed $hdspeed"
    else
        echo -e " HD:\t\t (\e[43mMultiple partitions to check not allowed yet\e[0m) / inkling speed $hdspeed"
    fi

    # Velocidad de Red (usando curl en lugar de wget)
    speed_bps=$(curl -s -o /dev/null -w '%{speed_download}' http://cachefly.cachefly.net/10mb.test 2>/dev/null)
    if [[ -n "$speed_bps" ]]; then
        speed_mbps=$(awk "BEGIN {print $speed_bps / 1024 / 1024}")
        extra=""
        if (( $(awk 'BEGIN {print ('"$speed_mbps"' > 12)}') )); then
            extra="(\e[42mprobably Gigabit Port\e[0m)"
        fi
        printf " cachefly 10MB:\t %.1f MB/s %b\n" "$speed_mbps" "$extra"
    else
        echo -e " cachefly 10MB:\t (Test failed)"
    fi

fi

echo " "
# END
