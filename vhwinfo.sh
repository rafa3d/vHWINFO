###############################################################################################
# vHWINFO - Get information about your virtual (or non) server                                #
# vHWINFO 1.0 Oct 2014                                                                        #
# Author: Rafa Marruedo <webmaster@vhwinfo.tk>                                               #
# URL: https://vhwinfo.tk/                                                                   #
###############################################################################################
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY. YOU USE AT YOUR OWN RISK. THE AUTHOR
# WILL NOT BE LIABLE FOR DATA LOSS, DAMAGES, LOSS OF PROFITS OR ANY
# OTHER  KIND OF LOSS WHILE USING OR MISUSING THIS SOFTWARE.
# See the GNU General Public License for more details.

#!/bin/bash

clear

echo "          ____                                                   ";
echo "    _____/\   \            __  ___       _______   ____________  ";
echo "   /\   /  \___\    _   _ / / / / |     / /  _/ | / / ____/ __ \ ";
echo "  /  \  \  /   /   | | / / /_/ /| | /| / // //  |/ / /_  / / / / ";
echo " /    \  \/___/ \  | |/ / __  / | |/ |/ // // /|  / __/ / /_/ /  ";
echo "/      \_________\ |___/_/ /_/  |__/|__/___/_/ |_/_/    \____/   ";
echo "\      /         / vHWINFO 1.1 May 2015 | https://vhwinfo.tk     ";
echo " ";



hostname=`hostname`
if [[ "$hostname" == *.* ]]
then
echo -e -n " hostname:\t "`hostname`
else
echo -e -n " hostname:\t "`hostname`.`dnsdomainname`
fi

ip=$(curl -4 -s ifconfig.me)
echo " (public ip "$ip")"

if hash sw_vers 2>/dev/null; then

# --------------------- MAC

virtual="It is not virtual, is dedicated"

echo -e " SO:\t\t "`sw_vers -productName` `sw_vers -productVersion`" (build "`sw_vers -buildVersion`")"

kernel_version=`system_profiler SPSoftwareDataType | grep 'Kernel Version:'`

echo -e " kernel:\t "${kernel_version:22}
echo -e " virtual:\t "$virtual

cpu=`sysctl -a machdep.cpu.brand_string`
echo -e " CPU:\t\t "${cpu:26}
cores=`sysctl hw.ncpu | awk '{print $2}'`
#cores=$((cores/2))
echo -e -n " vcpu:\t\t "$cores
if [[ $cores>1 ]]
then
echo " cores"
else
echo " core"
fi

ram=`sysctl hw.memsize`
ram=${ram:12}
ram=$((ram/1024/1024))
echo -e -n " RAM:\t\t "$ram "MB"
#if [[ $ram>1024 ]] then echo "gigas" fi
free=`vm_stat | grep 'Pages free:'`
free=${free:12}
free=${free%.*}
free=$((free*4))
free=$((free/1024))
free=$((free*100))
free=$((free/ram))
used=$((100-$free))
echo " ("$used"% used)"

hd=`diskutil info /dev/disk0 | grep 'Total Size:'`
hd=${hd:29}
hd=${hd%.*}

echo -e " HD:\t\t "$hd "GB"

speed="`wget -O /dev/null http://cachefly.cachefly.net/1mb.test 2>&1 | grep '\([0-9.]\+ [KM]B/s\)'`"
#pos=`expr index "$speed" "s"`
#echo $pos
speed=${speed:21}
speed=${speed%)*}
echo -e " cachefly 1Mb:\t "$speed

# --------------------- LINUX
else

virtual="It is not virtual, \e[42mis dedicated\e[0m"


kernel_version=`uname -r`

MACHINE_TYPE=`uname -m`
if [ ${MACHINE_TYPE} == 'x86_64' ]; then
bits=" 64 bits"  # 64-bit stuff here
else
bits=" 32 bits"  # 32-bit stuff here
fi


if hash lsb_release 2>/dev/null; 

then

soalt=`lsb_release -d`
echo -e " SO:\t\t "${soalt:13} $bits

else

so=`cat /etc/issue`

pos=`expr index "$so" 123456789`

so=${so/\/}


extra=""


if [[ "$so" == Debian*6* ]]; 
then
extra="(squeeze)"
fi

if [[ "$so" == Debian*7* ]]; 
then
extra="(wheezy)"
fi

if [[ "$so" == *Proxmox* ]]; 
then
so="Debian 7.6 (wheezy)";
fi

otro=`expr index "$so" \S`

if [[ "$otro" == 2 ]]; 
then
so=`cat /etc/*-release`
pos=`expr index "$so" NAME`
pos=$((pos-2))
so=${so/\/}
fi



echo -e " SO:\t\t "${so:0:($pos+2)} $extra$bits


fi

 
echo -e " kernel:\t "$kernel_version


if hash ifconfig 2>/dev/null; then
eth=`ifconfig`
else
eth=""
fi

virtualx=`dmesg`


if [[ "$eth" == *eth0* ]]; 
then
#virtual="It is not virtual, \e[42mis dedicated\e[0m"

if [[ "$virtualx" == *kvm-clock* ]]; 
then
virtual="KVM"
fi

if [[ "$virtualx" == *"VMware Virtual Platform"* ]]; 
then
virtual="VMware"
fi

if [[ "$virtualx" == *"Parallels Software International"* ]]; 
then
virtual="Parallels"
fi

if [[ "$virtualx" == *VirtualBox* ]]; 
then
virtual="VirtualBox"
fi



else

if [ -f /proc/user_beancounters ]
then
virtual="OpenVZ"
fi

fi

if [ -e /proc/xen ]
then
virtual="Xen"
fi



echo -e " virtual:\t "$virtual


cpu=`cat /proc/cpuinfo | grep "model name" | head -n 1`
bogo=`cat /proc/cpuinfo | grep "bogomips" | head -n 1`

 
cores=`grep -c processor /proc/cpuinfo`

   
if [[ "$cores" > 1 ]];
then
label="cores"
else
label="core"
fi

echo -e " cpu:\t\t "${cpu:13}
echo -e " vcpu:\t\t "$cores $label / ${bogo:11} bogomips



mem=`free -m`

pos=`expr index "$mem" M`
ram=${mem:($pos+10):10}
ram=${ram//[[:blank:]]/}

pos=`expr index "$mem" p`
swap=${mem:($pos+10):10}
swap=${swap//[[:blank:]]/}

busy=`free -t -m | egrep Mem | awk '{print $3}'`
busy=$((busy*100))
busy=$((busy/ram))

busy_swap=`free -t -m | egrep Swap | awk '{print $3}'`
busy_swap=$((busy_swap*100))
if (($swap>0))
then
busy_swap=$((busy_swap/swap))
fi

if (($busy>75)) 
then
label1="\e[43m"
label2="\e[0m"
else
label1=""
label2=""
if (($busy>90)) 
then
label1="\e[41m"
label2="\e[0m"
else
label1=""
label2=""
fi

fi


echo -e " RAM:\t\t "$ram" MB ("$label1$busy"% used"$label2")" / swap $swap MB "("$busy_swap"% used)"

total=`df -h --total | grep 'total' | awk '{print $2}'`
used=`df -h --total | grep 'total' | awk '{print $5}'`
used="${used//%}"

if (($used>75)) 
then
label1="\e[43m"
label2="\e[0m"
else
label1=""
label2=""

if (($used>90)) 
then
label1="\e[41m"
label2="\e[0m"
else
label1=""
label2=""
fi

fi



hdspeed=`dd if=/dev/zero of=ddfile bs=16k count=12190 2>&1`
sync
rm -rf ddfile
hdspeed1=" / inkling speed "`echo $hdspeed | grep "s, " | awk '{print $14}'`
hdspeed2=`echo $hdspeed | grep "s, " | awk '{print $15}'`

if (($used>0)) 
then
echo -e " HD:\t\t "$total "("$label1$used"% used"$label2")"$hdspeed1 $hdspeed2
else
echo -e " HD:\t\t (\e[43mMultiple partitions to check not allowed yet\e[0m)"$hdspeed1 $hdspeed2
fi




speed="`wget -O /dev/null http://cachefly.cachefly.net/10mb.test 2>&1 | grep '\([0-9.]\+ [KM]B/s\)'`"
pos=`expr index "$speed" "s"`

unidad=${speed:($pos-4):4}
speed=${speed:21:($pos-25)}

if [[ "$unidad" == "MB/s" ]]; 
then
pos=`expr index "$speed" .`
if (($pos<1))
then
pos=`expr index "$speed" ,`
fi

num=${speed:0:$pos-1}

if (($num>12)) 
then
extra="(\e[42mprobably Gigabit Port\e[0m)"
else
extra=""
fi

fi

echo -e " cachefly 10MB:\t "$speed $unidad $extra


fi

echo " "

# END
