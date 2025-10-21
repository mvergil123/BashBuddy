#!/bin/bash
# Welcome to my bash buddy script :)

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
# Quick Webscan function
QuickWebscan(){
	# Declaring color variables
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	NORMAL='\033[0m'

	# getting arguments
	ip="$1"	# get ip
	port="$2"	# get port

	# Running dirsearch

	echo -e "${GREEN}[+]Running dirsearch on port $port ${NORMAL}"

	dirsearch -u "http://$ip" -x 403,404 -o "results/$ip/dirsearch_port$port.txt" &> /dev/null
	echo "\n----------------------- Curl Report -----------------------\n" >> "results/$ip/dirsearch_port$port.txt"
	curl -s "http://$ip" >> "results/$ip/dirsearch_port$port.txt"


	# All done :)
	rm -r reports
	echo " " 
	echo -e "${GREEN}[+]The results of the dirsearch scan has been saved in the results directory :)${NORMAL}" 

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
		# run quick webscan on port 80
		QuickWebscan "$ip" 80
	fi
	if IsPortOpen "$ip" 443; then
		# run quick webscan on port 80
		QuickWebscan "$ip" 443
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
# Quick Port Scan function
QuickPortScan(){
	# Declaring color variables
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	NORMAL='\033[0m'

	ip="$1"	# get ip

	echo -e "${GREEN}[+]Running nmap scan of top 100 ports on target ip${NORMAL}"

	# run nmap on top 100 ports
	nmap --top-ports 100 -sV -T4 --open -oG "results/$ip/quick_nmap.grep" -oN "results/$ip/quick_nmap.txt" "$ip" &> /dev/null </dev/null &


	# print out some open ports that were found
	if [[ -s "results/$ip/quick_nmap.grep" ]]; then
  		echo "[+] Quick scan summary for $ip:"
  		# Print each open port and service/version
  		grep "/open" "results/$ip/quick_nmap.grep" | \
		sed -n 's/.*Ports: //p' | \
		tr ',' '\n' | \
		awk -F'/' '{ port=$1; state=$2; proto=$3; svc=$4; ver=substr($0,index($0,$7)); gsub(/^ +| +$/, "", ver); printf "  - %s/%s %s %s\n", port, proto, svc, ver }'
	else
  		echo -e "${RED}[!] No greppable output found at results/$ip/quick_nmap.grep${NORMAL}"
	fi

	echo -e "${GREEN}[+]The results of the nmap scan has been saved in the results directory :)${NORMAL}"
	echo " "
	
	# check if ports 80/443 are open and offer a quick webscan 
	if IsPortOpen "$ip" 80 || IsPortOpen "$ip" 443; then
		# ask the user if they would like to run quick webscan 
		read -p "A web port (80/443) was detected open. Would you like to run Quick_Webscan? (y/N): " yn
		if [[ "${yn,,}" == "y" ]]; then
			if IsPortOpen "$ip" 80 && IsPortOpen "$ip" 443; then
			# run quick webscan on both
				QuickWebscan "$ip" 443
				QuickWebscan "$ip" 80

			elif IsPortOpen "$ip" 80; then
			# run quick webscan on port 80
				QuickWebscan "$ip" 80

			else 
			# run quick webscan on port 443
				QuickWebscan "$ip" 443
			fi

		fi

	fi

}
#-------------------------------------------------------------------------------------------------------------------------
# Summarize function 
Summary() {
    local ip="$1"
    local dir="results/$ip"
    local summary="$dir/summary.txt"
    mkdir -p "$dir"

    # header
    {
      printf "BashBuddy Recon Summary\n"
      printf "Target: %s\n" "$ip"
      printf "Generated: %s\n\n" "$(date -u +"%Y-%m-%d %H:%M:%SZ")"
    } > "$summary"

    # 1) Open ports summary (prefer grepable output)
    {
      echo "== Open ports =="
      if [[ -f "$dir/quick_nmap.grep" ]]; then
        # lines with open ports
        grep "/open" "$dir/quick_nmap.grep" | sed -n 's/.*Ports: //p' | \
          tr ',' '\n' | sed 's/^ *//;s/ *$//' | awk -F'/' '{printf "  - %s/%s %s\n", $1,$3,$4}'
      elif [[ -f "$dir/nmap.grep" ]]; then
        grep "/open" "$dir/nmap.grep" | sed -n 's/.*Ports: //p' | \
          tr ',' '\n' | sed 's/^ *//;s/ *$//' | awk -F'/' '{printf "  - %s/%s %s\n", $1,$3,$4}'
      elif [[ -f "$dir/quick_nmap.txt" ]]; then
        # fallback parse -oN human output
        awk '
          /^PORT[[:space:]]+STATE[[:space:]]+SERVICE/ {found=1; next}
          found && NF==0 {exit}
          found {printf "  - %s %s %s\n", $1, $2, substr($0, index($0,$3))}
        ' "$dir/quick_nmap.txt"
      else
        echo "  (no nmap output found)"
      fi
      echo
    } >> "$summary"

    # 2) Web findings (dirsearch & curl)
    {
      echo "== Web findings =="
      local web_found=false

      if [[ -f "$dir/dirsearch_port80.txt" ]]; then
        web_found=true
        echo "Port 80 (/http) dirsearch matches:"
        # print unique interesting endpoints (login/admin/wp etc)
        grep -iE "login|admin|wp-|wp-login|portal|signin|dashboard" "$dir/dirsearch_port80.txt" 2>/dev/null | sed 's/^/  - /' | sort -u
        # extract <title> if curl appended
        if grep -qi "<title" "$dir/dirsearch_port80.txt"; then
          echo "HTTP page title(s):"
          grep -oP '(?i)(?<=<title>).*?(?=</title>)' "$dir/dirsearch_port80.txt" 2>/dev/null | sed 's/^/  - /' | head -n 5
        fi
      fi

      if [[ -f "$dir/dirsearch_port443.txt" ]]; then
        web_found=true
        echo "Port 443 (/https) dirsearch matches:"
        grep -iE "login|admin|wp-|wp-login|portal|signin|dashboard" "$dir/dirsearch_port443.txt" 2>/dev/null | sed 's/^/  - /' | sort -u
        if grep -qi "<title" "$dir/dirsearch_port443.txt"; then
          echo "HTTPS page title(s):"
          grep -oP '(?i)(?<=<title>).*?(?=</title>)' "$dir/dirsearch_port443.txt" 2>/dev/null | sed 's/^/  - /' | head -n 5
        fi
      fi

      if [[ "$web_found" = false ]]; then
        echo "  (no web findings files present)"
      fi
      echo
    } >> "$summary"

    # 3) Hydra results (HTTP/HTTPS/SSH)
    {
      echo "== Hydra findings =="
      local found_any=false
      for f in "$dir"/hydra_*; do
        [[ -f "$f" ]] || continue
        # skip header lines starting with #
        if grep -q 'login:' "$f" 2>/dev/null; then
          found_any=true
          echo "Results from $(basename "$f"):"
          # print only non-comment lines which contain 'login:' and 'password:'
          grep -v '^#' "$f" | grep -E 'login:|password:' | sed 's/^/  /' | head -n 50
        fi
      done
      if [[ "$found_any" = false ]]; then
        echo "  (no hydra results found)"
      fi
      echo
    } >> "$summary"

    # 4) Notes & next steps
    {
      echo "== Notes & suggested next steps =="
      # Recommend checks based on findings
      if grep -q "/open" "$dir/quick_nmap.grep" 2>/dev/null || grep -q "22/" "$dir/quick_nmap.txt" 2>/dev/null; then
        echo "  - SSH (22) found: attempt SSH login if credentials available or check for key-based auth."
      fi
      if grep -q "80/" "$dir/quick_nmap.grep" 2>/dev/null || grep -q "443/" "$dir/quick_nmap.grep" 2>/dev/null; then
        echo "  - Web ports found: review dirsearch output and try authenticated actions if Hydra found creds."
      fi
      echo "  - Raw outputs available in: $dir"
      echo
    } >> "$summary"

    # final note
    echo "[*] Summary written to $summary"
}
#-------------------------------------------------------------------------------------------------------------------------
# Menu Function
Menu(){
	ip=$1
	# Prompt the menu to the user
	figlet -f small "Menu"
	echo "1) Full Recon"
	echo "2) Quick Port Scan"
	echo "3) Quick Webscan"
	echo "4) Custom command"
	echo "5) Exit"
	read -p "What would you like to do with the target? " menu_choice

	if [ "$menu_choice" != 5 ]; then
		mkdir -p results/$ip # create results dir if not already created
		echo -e  "${GREEN}Results directory has been created. You can now view the output of the scans as they are occurring.${NORMAL} "
	fi

	# switch case for selecting option
	case "$menu_choice" in 
		1) Full_Recon "$ip"
		;;
		2) QuickPortScan "$ip"	# Quick port Scan 
		;;
		3)	exit 1
	esac

	# run the summarize function 
	Summary "$ip"
	
}
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
# Main part of the program 

# Acquire the IP address of the target machine
read -p  "Please input the IP address of the target: " IP_Address

# Ping the target to ensure that it is online (pinging first and then if it fails trying nc )
ping -c 1 $IP_Address > /dev/null 2>&1	# pinging the target and silence the output (more aesthetic)

if [ $? -eq 0 ]; then	# the machine is active
	# prompt the menu
	echo -e "${GREEN}[+] Host is up${NORMAL}"

else	# ping failed :(
	isHostUp=false
	echo -e "${RED}[+] Ping Failed${NORMAL}"
	echo "Trying netcat scans on common ports in case ping is blocked..."
	for port in 22, 80, 443; do  # for loop of common ports to run with netcat in case ICMP is blocked but machine is up
		nc -z -w2 $IP_Address $port > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo -e "${GREEN}[+] Host is up${NORMAL}"
			isHostUp=true
			break
		fi
	done

	if [ "$isHostUp" = false ]; then 
		echo -e "${RED}[+] Target is not active or unreachable. Exiting :(${NORMAL}"
		exit 1
	fi 
fi

# present the menu to the user
Menu "$IP_Address"

