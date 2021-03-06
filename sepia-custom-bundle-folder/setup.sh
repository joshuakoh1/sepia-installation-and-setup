#!/bin/bash
# test root
if [[ $EUID -eq 0 ]]; then
    echo "It seems that you are running this script as root. This is NOT supported and might cause the setup to fail!"
    echo "Are you sure that you want to continue?"
    read -p "Enter 'yes' to continue: " yesno
    echo ""
	if [ -n "$yesno" ] && [ $yesno = "yes" ]; then
		echo "Ok. Good luck ;-)"
	else
        echo "Aborted. Please start the setup without 'sudo' or with a user other than root."
        echo "cu later :-)"
        exit
    fi
fi
# system check methods
is_arm() {
  case "$(uname -m)" in
    *arm*) return 0 ;;
    *) return 1 ;;
  esac
}
is_64() {
  case "$(uname -m)" in
    *64*) return 0 ;;
    *) return 1 ;;
  esac
}
#
# make scripts executable
find . -name "*.sh" -exec chmod +x {} \;
chmod +x elasticsearch/bin/elasticsearch
#
# set local Java path
if [ -f "java/version" ]; then
    new_java_home=$(cat java/version)
    export JAVA_HOME=$(pwd)/java/$new_java_home
    export PATH=$JAVA_HOME/bin:$PATH
	echo "Found local Java version: $JAVA_HOME"
fi
#
# get name of main server JAR file (latest version)
cd sepia-assist-server
JAR_NAME=$(ls | grep "^sepia-assist.*jar" | tail -n 1)
#
# start interactive setup
echo ""
echo "Welcome to the SEPIA framework!"
echo ""
echo "This little script will help you with the configuration of your server."
echo "If you are here for the first time please take 5 minutes to read the (MIT) license agreement, especially the part about 'no-warranty' ^_^."
echo "You can find the license file in your download folder, in the SEPIA app or on one of the SEPIA pages, e.g.:"
echo "https://github.com/SEPIA-Framework/sepia-assist-server"
echo ""
echo "If you don't know what to do next read the guide at:"
echo "https://github.com/SEPIA-Framework/sepia-installation-and-setup#quick-start"
echo ""
echo "Typically for a new installation what you should do is start ES (4) then setup the database and create the admin and assistant accounts (1)."
echo "Installation of the TTS engine (7) is required if you're planning to use a DIY SEPIA Client (and recommended for fun)."
echo "After that type the IP address or hostname of this machine into your SEPIA-Client login-screen and you are good to go :-)"
# check commandline arguments
option=""
argument1=""
argument2=""
breakafterfirst="false"
if [ -n "$1" ]; then
    option=$1
	breakafterfirst="true"
	if [ -n "$2" ]; then
		argument1=$2
		if [ -n "$3" ]; then
			argument2=$3
		fi
	fi
fi
# stat menu loop
while true; do
	echo ""
	echo "What would you like to do next?"
	echo "1: Setup all components (except dynamic DNS). Note: requires step 4."
	echo "2: Define new admin and assistant passwords"
	echo "3: Setup dynamic DNS with DuckDNS"
	echo "4: Start Elasticsearch"
	echo "5: Set hostname of this machine to 'sepia-home' (works e.g. for Debian/Raspian Linux)"
	echo "6: Suggest cronjobs for server (open cronjobs manually with 'crontab -e' and copy/paste lines)"
	echo "7: Install TTS engine and voices"
	echo "8: Install Java locally into SEPIA folder"
	echo ""
	if [ -z "$option" ]; then
		read -p "Enter a number plz (0 to exit): " option
	else
		echo "Selected by cmd argument: $option"
    fi
	echo ""
	if [ -z "$option" ] || [ $option = "0" ]
	then
		break
	elif [ $option = "1" ]
	then
		if [ -n "$argument1" ]; then
			java -jar $JAR_NAME setup $argument1
		else
			java -jar $JAR_NAME setup --my
		fi
		echo "------------------------"
		echo "Please check the screen for errors. If you saw nothing suspicious you can continue with:"
		echo ""
		echo "1) TTS engine installation (menu entry 7, optional but recommended)"
		echo "2) Set up NGINX to secure your server: bash setup-nginx.sh (optional but recommended)"
		echo "3) Start SEPIA server: bash run-sepia.sh"
		echo ""
		echo "When you're done and everything works as expected check out the suggested cronjobs (step 6) to run SEPIA automatically."
		echo "If you want to use your own auto-start procedure please include the commands from either 'on-reboot.sh' or 'on-docker.sh'."
		echo "------------------------"
	elif [ $option = "2" ] 
	then
		if [ -n "$argument1" ]; then
			java -jar $JAR_NAME setup accounts $argument1
		else
			java -jar $JAR_NAME setup accounts --my
		fi
	elif [ $option = "3" ] 
	then
		if [ -n "$argument1" ]; then
			java -jar $JAR_NAME setup duckdns $argument1
		else
			java -jar $JAR_NAME setup duckdns --my
		fi
		echo "------------------------"
		echo "DONE. Please restart 'SEPIA assist server' to activate DuckDNS worker!"
		echo "------------------------"
	elif [ $option = "4" ] 
	then	
		cd ..
		cd elasticsearch
		./run.sh
		if [ $? -eq 0 ]; then
			./wait.sh
			cd ..
			cd sepia-assist-server
			echo "------------------------"
			echo "DONE."
			echo "------------------------"
		else
			echo "------------------------"
			echo "FAILED to start Elasticsearch"
			echo "------------------------"
		fi
	elif [ $option = "5" ] 
	then
		sudo sh -c "echo 'sepia-home' > /etc/hostname"
		sudo sed -i -e 's|127\.0\.1\.1.*|127.0.1.1	sepia-home|g' /etc/hosts
		echo "------------------------"
		echo "Please reboot the system to use new hostname."
		echo "------------------------"
	elif [ $option = "6" ] 
	then
		echo "------------------------"
		echo "Cronjob suggestions:"
		echo ""
		echo '@reboot sleep 60 && ~/SEPIA/on-reboot.sh;'
		echo '30 4 1-31/2 * * ~/SEPIA/cronjob.sh;'
		echo "------------------------"
	elif [ $option = "7" ] 
	then
		echo "Installing TTS engine and voices:"
		mkdir -p tmp/deb
		cd tmp/deb
		sudo apt-get update
		sudo apt-get install -y espeak-ng espeak-ng-espeak
		sudo apt-get install -y --no-install-recommends flite-dev flite
		if is_arm;
		then
			sudo apt-get install -y --no-install-recommends libttspico-data
			wget http://ftp.de.debian.org/debian/pool/non-free/s/svox/libttspico0_1.0+git20130326-9_armhf.deb
			wget http://ftp.de.debian.org/debian/pool/non-free/s/svox/libttspico-utils_1.0+git20130326-9_armhf.deb
			# apt-get install -f ./libttspico0_1.0+git20130326-9_armhf.deb ./libttspico-utils_1.0+git20130326-9_armhf.deb
			sudo dpkg -i libttspico0_1.0+git20130326-9_armhf.deb
			sudo dpkg -i libttspico-utils_1.0+git20130326-9_armhf.deb
		elif is_64;
		then
			wget http://ftp.de.debian.org/debian/pool/non-free/s/svox/libttspico-data_1.0+git20130326-9_all.deb
			wget http://ftp.de.debian.org/debian/pool/non-free/s/svox/libttspico0_1.0+git20130326-9_amd64.deb
			wget http://ftp.de.debian.org/debian/pool/non-free/s/svox/libttspico-utils_1.0+git20130326-9_amd64.deb
			sudo dpkg -i libttspico-data_1.0+git20130326-9_all.deb
			sudo dpkg -i libttspico0_1.0+git20130326-9_amd64.deb
			sudo dpkg -i libttspico-utils_1.0+git20130326-9_amd64.deb
		else
			wget http://ftp.de.debian.org/debian/pool/non-free/s/svox/libttspico-data_1.0+git20130326-9_all.deb
			wget http://ftp.de.debian.org/debian/pool/non-free/s/svox/libttspico0_1.0+git20130326-9_i386.deb
			wget http://ftp.de.debian.org/debian/pool/non-free/s/svox/libttspico-utils_1.0+git20130326-9_i386.deb
			sudo dpkg -i libttspico-data_1.0+git20130326-9_all.deb
			sudo dpkg -i libttspico0_1.0+git20130326-9_i386.deb
			sudo dpkg -i libttspico-utils_1.0+git20130326-9_i386.deb
		fi
		cd ../..
		rm -rf tmp
		echo "------------------------"
		echo "DONE."
		echo "NOTE: MaryTTS server is available as extension, see folder: "
		echo "sepia-assist-server/Xtensions/TTS/marytts/INSTALL.md"
		echo "------------------------"
	elif [ $option = "8" ] 
	then
		echo "------------------------"
		echo "Please go to the folder 'java' and run the script for your specific platform. Afterwards restart this setup and check if local Java is indicated at start."
		echo "------------------------"
	else
		echo "------------------------"
		echo "Not an option, please try again."
		echo "------------------------"
	fi
	option=""
	argument1=""
	argument2=""
	if [ $breakafterfirst = "true" ]
	then
		break
	fi
done
