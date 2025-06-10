#!/bin/bash
# Welcome to my bash buddy script :)

# ASCII banner for a sick intro
clear
figlet "BashBuddy"
echo "Your lazy pentest pal"
echo


# Section to declare color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
NORMAL='\033[0m'

# Acquire the IP address of the target machine
read -p  "Please input the IP address of the target: " IP_Address

# Ping the target to ensure that it is online (pinging first and then if it fails trying nc )
ping -c 1 $IP_Address > /dev/null 2>&1  # pinging the target and silence the output (more aesthetic)

if [ $? -eq 0 ]; then   # the machine is active
        # prompt the menu
        echo -e "${GREEN}[+] Host is up${NORMAL}"

else    # ping failed :(
        echo -e "${RED}[+] Ping Failed${NORMAL}"
        echo "Trying netcat scans on common ports in case ICMP is blocked..."
        for port in 22, 80, 443; do  # for loop of common ports to run with netcat in case ICMP is blocked but machine is up
                nc -z -w2 $IP_Address $port > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        echo -e "${GREEN}[+] Host is up${NORMAL}"
                        break
                fi
        done
        echo -e "${RED}[+] The machine is not active :(${NORMAL}"
fi
