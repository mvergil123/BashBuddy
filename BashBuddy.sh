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
ping -c 1 $IP_Address > /dev/null 2>&1	# pinging the target and silence the output (more aesthetic)

if [ $? -eq 0 ]; then	# the machine is active
	# prompt the menu
	echo -e "${GREEN}[+] Host is up${NORMAL}"

else	# ping failed :(
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
	nc -z -w1 "$ip" "$port" > /dev/null 2>&1	# check if port is opened	# Return True or False
}
#-------------------------------------------------------------------------------------------------------------------------
# Function that gathers custom usernames and passwords and stores them in temp files
Get_usernames_passwords(){
	userf="$1"	# temp file for usernames
        passwdf="$2"	# temp file for passwords
       	echo "Input usernames (input 'done' when finished):"
        while true; do
        	read -rp "Username: " username
               	if [[ "${username,,}" = "done" ]]; then
                    break
		fi
                echo "$username" >> "$userf"    # storing username input in file
         done
         echo "Input passwords (input 'done' when finished):"
         while true; do
         	read -rp "Password: " password
                if [[ "${password,,}" = "done" ]]; then
                	break
		fi
                echo "$password" >> "$passwdf"  # storing passwd input in file
          done
}
#-------------------------------------------------------------------------------------------------------------------------
# Function to run hydra on login page
Run_hydra(){
	port=$1
	ip=$2
	errorstr=$3
	echo "Would you like to add any possible usernames/passwords that you think might work?"
        read -p "(Y) or (N) " user_choice
        # user wants to use their own username and passwords
        if [[ "${user_choice,,}" = "y" ]]; then         # check for both lowercase and uppercase
        		userf="results/$ip/usernames.txt"      # Creating temp file for usernames
                passwdf="results/$ip/passwords.txt"    # Creating temp file for passwords

                Get_usernames_passwords userf passwdf

		case "$port" in
        80)
            # hydra on port 80
            hydra -L "$userf" -P "$passwdf" "$ip" http-post-form \
            "/login.php:username=^USER^&password=^PASS^:F=$errorstr" \
            -o "results/$ip/hydra_http_login.txt" &> /dev/null
            ;;
        443)
            # hydra on port 443
            hydra -L "$userf" -P "$passwdf" "$ip" https-post-form \
            "/login.php:username=^USER^&password=^PASS^:F=$errorstr" \
            -o "results/$ip/hydra_https_login.txt" &> /dev/null
            ;;
    esac
		
# running hydra normally
        else
        # ask the user for the path to the wordlist
        userf="results/$ip/usernames.txt"       # creating a generic username file to use with hydra
        echo -e "root\nadmin\nuser\ntest\nubuntu\nguest" > "$userf"
        read -rp "Please input the path to the wordlist you would like to use for hydra: " path
		case "$port" in
			80)
				# hydra on port 80
				hydra -L "$userf" -P "$path" "$ip" http-post-form \
				"/login.php:username=^USER^&password=^PASS^:F=$errorstr" \
				-o "results/$ip/hydra_http_login.txt" &> /dev/null
			;;
			443)
				# hydra on port 443
				hydra -L "$userf" -P "$path" "$ip" https-post-form \
				"/login.php:username=^USER^&password=^PASS^:F=$errorstr" \
				-o "results/$ip/hydra_https_login.txt" &> /dev/null
			;;
		esac
		fi
    read -rp "Delete temporary username/password files? (Y) or (N): " del_choice
	if [[ "${del_choice,,}" = "y" ]]; then
    	rm -f "$userf" "$passwdf"
    	echo "Temporary files deleted."
	fi
}
#-------------------------------------------------------------------------------------------------------------------------
# Full Recon Function
Full_Recon(){
	#Section to declare color variables
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	NORMAL='\033[0m'

	echo "Commencing Full Recon. This may take a while...."
	ip="$1"

	# Verbose nmap scan on IP for open ports
	nmap -vv -sV -p- -oG results/$ip/nmap.grep "$ip" &> /dev/null	# verbose nmap scan on all ports and write results to file
	echo -e "${GREEN}[+] Nmap scan completed${NORMAL}"

	# Check if ports 80 or 443 are opened to utilize dirsearch and curl
	if IsPortOpen "$ip" 80; then
		dirsearch -u "http://$ip" -x 403,404 -o "results/$ip/dirsearch_port80.txt" &> /dev/null
		echo "\n----------------------- Curl Report -----------------------\n" >> "results/$ip/dirsearch_port80.txt"
		curl -s "http://$ip" >> "results/$ip/dirsearch_port80.txt"
	fi
	if IsPortOpen "$ip" 443; then
		dirsearch -u "https://$ip" -x 403,404 -o "results/$ip/dirsearch_port443.txt" &> /dev/null
		echo "\n----------------------- Curl Report -----------------------\n" >> "results/$ip/dirsearch_port443.txt"
		curl -sk "https://$ip" >> "results/$ip/dirsearch_port443.txt"
	fi
	rm -rf reports	# removing the default dir created by dirsearch

	echo -e "${GREEN}[+] Dirsearch and curl completed${NORMAL}"

	# Brute force port 22 if opened with Hydra
	if IsPortOpen "$ip" 22; then
		echo "Port 22 is open for ssh"
		read -rp "Would you like to run hydra on the port 22? (Y) or (N) " choice
		if [[ "${choice,,}" = "y" ]]; then
			echo "Would you like to add any possible usernames/passwords that you think might work?"
			read -p "(Y) or (N) " user_choice

			# user wants to use their own username and passwords
			if [[ "${user_choice,,}" = "y" ]]; then		# check for both lowercase and uppercase
				userf="results/$ip/usernames.txt"      # Creating temp file for usernames
				passwdf="results/$ip/passwords.txt"    # Creating temp file for passwords

				Get_usernames_passwords "$userf" "$passwdf"
				hydra -L "$userf" -P "$passwdf" ssh://"$ip" -o "results/$ip/hydra_ssh.txt" &> /dev/null

			# running hydra normally
			else
			# ask the user for the path to the wordlist
				userf="results/$ip/usernames.txt"	# creating a generic username file to use with hydra
				echo -e "root\n admin\n user\n test\n ubuntu\n guest\n" > "$userf"
				read -rp "Please input the path to the wordlist you would like to use for hydra: " path
				hydra -L "$userf" -P "$path" ssh://"$ip" -o "results/$ip/hydra_ssh.txt" &> /dev/null
			fi
			echo -e "${GREEN}[+] Hydra completed on port 22${NORMAL}\n"
			read -rp "Delete temporary username/password files? (Y) or (N): " del_choice
			if [[ "${del_choice,,}" = "y" ]]; then
				rm -f "$userf" "$passwdf"
			fi
		fi
		echo "I don't blame you, Hydra takes a while :)"
	fi


	# if login page found with dirsearch, run hydra
	# checking if a login page is found on both port 80 and 443
	if [[ -f "results/$ip/dirsearch_port443.txt" ]] && grep -qi "login.php" "results/$ip/dirsearch_port80.txt" && grep -qi "login.php" "results/$ip/dirsearch_port443.txt"; then
		echo "${GREEN}[+]Login page was found on both http and https${NORMAL}"
		echo "1) HTTP only"
		echo "2) HTTPS only"
		echo "3) Both"
		echo "4) Neither"
		read -rp "Select what you would like to run hydra on: " choice
		if [[ "$choice" == "1" || "$choice" == "2" || "$choice" == "3" ]]; then
			read -p "To ensure most accuracy with hydra pls navigate to $ip/login.php and attempt any login. Please copy the error message and paste it here: " errorstr
		fi
		echo ""
		case "$choice" in
			1)
				Run_hydra 80 "$ip" "$errorstr"
			;;
			2)
				Run_hydra 443 "$ip" "$errorstr"
			;;
			3)
				Run_hydra 80 "$ip" "$errorstr"
				Run_hydra 443 "$ip" "$errorstr"
			;;
			4)
				echo -e "I don't blame you, hydra takes a while :)"
		esac

	# check if login page is found on port 80
	elif grep -q -i "login.php" "results/$ip/dirsearch_port80.txt"; then
		echo -e "${GREEN}[+]Login page was found on http${NORMAL}"
		read -rp "Would you like to run hydra on the site? (Y) or (N) " choice
		if [[ "${choice,,}" = "y" ]]; then
			read -p "To ensure most accuracy with hydra pls navigate to $ip/login.php and attempt any login. Please copy the error message and paste it here: " errorstr
			Run_hydra 80 "$ip" "$errorstr"
		fi

	# check if login page is found on port 443
	elif grep -q -i "login.php" "results/$ip/dirsearch_port443.txt"; then
		echo -e "${GREEN}[+]Login page was found on https${NORMAL}"
                read -rp "Would you like to run hydra on the site? (Y) or (N) " choice
		if [[ "${choice,,}" = "y" ]]; then
				read -p "To ensure most accuracy with hydra pls navigate to $ip/login.php and attempt any login. Please copy the error message and paste it here: " errorstr
                Run_hydra 443 "$ip" "$errorstr"
        fi

	# login page wasn't found on either port
	else
		echo -e "${RED}[+]Login page was not found :(${NORMAL}"
	fi

	# ALL DONE :)
	echo -e "${GREEN}[+] All done :)"
	echo -e "[+] You may now review all the recon collected in the results directory${NORMAL}"
	exit 1
}
#-------------------------------------------------------------------------------------------------------------------------
# Prompt the menu to the user
figlet -f small "Menu"
echo "1) Full Recon"
echo "2) Quick Port Scan"
echo "3) Quick Webscan"
echo "4) Custom command"
echo "5) Exit"
read -p "What would you like to do with the target? " user_choice
mkdir -p results/$IP_Address # create results dir if not already created
echo -e  "${GREEN}Results directory has been created. You can now view the output of the scans as they are occurring.${NORMAL} "


Full_Recon "$IP_Address"
