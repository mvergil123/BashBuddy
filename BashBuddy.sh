#!/bin/bash
# Welcome to my bash buddy script :)

#-------------------------------------------------------------------------------------------------------------------------
# ASCII banner for a sick intro
clear
figlet -f big "BashBuddy"
echo "Your lazy pentest pal"
echo
#-------------------------------------------------------------------------------------------------------------------------
# Section to declare color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
NORMAL='\033[0m'
#-------------------------------------------------------------------------------------------------------------------------
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
        echo -e "${RED}[+] Target is not active or unreachable. Exiting :(${NORMAL}"
        exit 1
fi
#-------------------------------------------------------------------------------------------------------------------------
# Is port open function for dirsearch
IsPortOpen(){
        ip="$1"
        port="$2"
        nc -z -w1 "$ip" "$port" > /dev/null 2>&1        # check if port is opened
        return $?       # Return True or False
}
#-------------------------------------------------------------------------------------------------------------------------
# Full Recon Function
Full_Recon(){
        echo "Commencing Full Recon. This may take a while...."
        ip="$1"
        mkdir -p results/$ip # create results dir if not already created

        # Verbose nmap scan on IP for open ports
        nmap -vv -sV -p- -oG results/$ip/nmap.grep "$ip"        # verbose nmap scan on all ports and write results to file
        echo -e "${GREEN}[+] Nmap scan completed${NORMAL}"

        # Check if ports 80 or 443 are opened to utilize dirsearch and curl
        if IsPortOpen "$ip" 80; then
                dirsearch -u "http://$ip" -x 403,404 -o "results/$ip/dirsearch_port80.txt"
                curl -s "http://$ip" >> "results/$ip/dirsearch_port80.txt"
        fi
        if IsPortOpen "ip" 443; then
                dirsearch -u "https://$ip" -x 403,404 -o "results/$ip/dirsearch_port443.txt"
                curl -sk "https://$ip" >> "results/$ip/dirsearch_port443.txt"
        fi
        echo -e "${GREEN}[+] Dirsearch and curl completed${NORMAL}"

        # Brute force port 22 is opened and any login page





}
#-------------------------------------------------------------------------------------------------------------------------
# Prompt the menu to the user
figlet -f small "Menu"
echo "1) Full Recon (nmap, dirsearch, curl, whois)"
echo "2) Quick Port Scan (nmap)"
echo "3) Quick Webscan (dirsearch)"
echo "4) Custom command"
echo "5) Exit"
read -p "What would you like to do with the target? " user_choice
