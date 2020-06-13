KEXT_PATH="$HOME/Desktop/AppleIntelWiFi.kext" # Change your kext path
PASSWORD="" #change your password for auto login
NETWORKS_PATH="$HOME/.networks" # change your path save networks infomation
INFO_PATH="$KEXT_PATH/Contents/Info.plist" # Do not change here

kext_load(){
    if [[ -z "$2" ]]; then
      PWD="(empty)"
    else
      PWD="$2"
    fi
    echo "Kext is loaded with wifi: \033[32m$1 \033[31m - \033[32m $PWD\033[00m"
    sudo kextload $KEXT_PATH;
}

write_new_network(){
    echo "<ssid>$1</ssid><pwd>$2</pwd>" >> $NETWORKS_PATH;
}
add_new_wifi(){
    echo "-----------------------"
    SSID=""
    PWD=""
    while [ -z "$SSID" ]
    do
        echo "Enter your wifi name:"
        read SSID
    done
    check_ssid_exists "$SSID"
    EXISTS=$?
    if [ $EXISTS == 1 ]; then
        echo "The wifi is already exists, enter new password for change:"
        read PWD;
        while [ -z "$PWD" ]
        do
            echo "Enter your wifi password:"
            read PWD
        done
        sed -i '' "s/<ssid>$SSID<\/ssid><pwd>.*<\/pwd>/<ssid>$SSID<\/ssid><pwd>$PWD<\/pwd>/g" $NETWORKS_PATH
    else
        echo "Enter your wifi password:"
        read PWD
        if [[ -z "$PWD" ]]; then
          echo "You enter password is empty"
        fi
        write_new_network "$SSID" "$PWD"
    fi
    replace "$1" "$SSID" "$2" "$PWD"
    kext_load "$SSID" "$PWD"
}

check_ssid_exists(){
    if [ -f "$NETWORKS_PATH" ]; then
        while read -r LINE; do
            PATTERN="^<ssid>(.+)</ssid><pwd>(.*)</pwd>$"
            if [[ $LINE =~ $PATTERN ]]; then
                if [[ "${BASH_REMATCH[1]}" == $1 ]]; then
                    return 1
                fi
            fi
        done < $NETWORKS_PATH
    fi
    return 0
}

replace(){
    case "$VERSION" in
        "1.1")
            KEY_SSID="BSSID"
            KEY_PWD="PWD"
            ;;
        "1.2.3")
            KEY_SSID="NWID"
            KEY_PWD="WPAKEY"
            replace_wpa "$4"
            ;;
        *)
        echo "This script doesn't support your kext version."
        exit;
    esac

    INFO_CONTENT=`cat $INFO_PATH | tr -d '\n\t' | sed "s/<key>$KEY_SSID<\/key><string>$1<\/string>/<key>$KEY_SSID<\/key><string>$2<\/string>/g"`
    INFO_CONTENT=`echo $INFO_CONTENT | sed "s/<key>$KEY_PWD<\/key><string>$3<\/string>/<key>$KEY_PWD<\/key><string>$4<\/string>/g"`
    echo $INFO_CONTENT | sudo tee $INFO_PATH > /dev/null
}
replace_wpa(){
    if [ -z "$1" ]; then
        INFO_CONTENT=`cat $INFO_PATH | tr -d '\n\t' | sed "s/<key>WPA\/WPA2<\/key><true\/>/<key>WPA\/WPA2<\/key><false\/>/g"`
    else
        INFO_CONTENT=`cat $INFO_PATH | tr -d '\n\t' | sed "s/<key>WPA\/WPA2<\/key><false\/>/<key>WPA\/WPA2<\/key><true\/>/g"`
    fi
    echo $INFO_CONTENT | sudo tee $INFO_PATH > /dev/null
}
connect_of_list(){
     if [ -f "$NETWORKS_PATH" ]; then
        INDEX=1
        while read -r LINE; do
            PATTERN="^<ssid>(.+)</ssid><pwd>(.*)</pwd>$"
            if [[ $LINE =~ $PATTERN ]]; then
                if [ $INDEX -eq $1 ]; then
                    replace "$2" "${BASH_REMATCH[1]}" "$3" "${BASH_REMATCH[2]}"
                    kext_load "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                fi
                INDEX=$((INDEX+1))
            fi
        done < $NETWORKS_PATH
    fi
    return 0
}

show_preferred(){
    if [ -f "$NETWORKS_PATH" ]; then
        N=1
        echo "-----------------------"
        echo "Select the wifi you want to connect:";
        while read -r LINE; do
            PATTERN="^<ssid>(.+)</ssid><pwd>(.*)</pwd>$"
            if [[ $LINE =~ $PATTERN ]]; then
                if [[ -z "${BASH_REMATCH[2]}" ]]; then
                  PWD="(empty)"
                else
                  PWD="${BASH_REMATCH[2]}"
                fi
                echo "$N. \033[32m${BASH_REMATCH[1]} - $PWD \033[00m";
                N=$((N+1))
            fi
        done < $NETWORKS_PATH
        echo "$N. \033[31mBack.\033[00m"
        read ANSWER
        if [ $ANSWER -ge $N ]; then 
            init "$1" "$2"
        else
            connect_of_list "$ANSWER" "$1" "$2"
        fi
    
    else
        touch $NETWORKS_PATH
        write_new_network "$1" "$2"
        show_preferred "$1" "$2"
    fi
}

init(){
    if [[ -z "$2" ]]; then
      PWD="(empty)"
    else
      PWD="$2"
    fi
    echo "-----------------------"
    echo "1. Connect to wifi:\033[32m $1 \033[0m-\033[32m $PWD\033[0m"
    echo "2. Display the list of connected wifi."
    echo "3. Connect to new wifi."
    echo "4. Exit."
    read ANSWER
    case $ANSWER in
        1)
            kext_load "$1" "$2"
            ;;
        2)
            show_preferred "$1" "$2"
            ;;
        3)
            add_new_wifi "$1" "$2"
            ;;
        4)
            exit
            ;;    
        *)
            init "$1" "$2"
    esac
}

_init(){
    NETWORK_PATTERN="<key>$1<\/key><string>([a-zA-Z0-9_\-\#[:space:]\@\!\$\^\&\*\.\(\)\+\=\/]+)<\/string>(.*)<key>$2<\/key><string>([a-zA-Z0-9_\-\#[:space:]\@\!\$\^\&\*\.\(\)\+\=\/]*)<\/string>";
    if [[ $INFO_CONTENT =~ $NETWORK_PATTERN ]]; then
        if [ ! -z $PASSWORD ]; then
           echo $PASSWORD | sudo -S echo ""
           echo "\033[32m Login successfully !!\033[0m";
        fi
        init "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
    else
        echo "This script doesn't get your current wifi."
    fi
}

INFO_CONTENT=`cat $INFO_PATH | tr -d '\n\t'`;
VERSION_PATTERN="<key>CFBundleShortVersionString<\/key><string>([0-9\.]+)<\/string>"

if [[ $INFO_CONTENT =~ $VERSION_PATTERN ]]; then
    VERSION="${BASH_REMATCH[1]}"
    case "${BASH_REMATCH[1]}" in
        "1.1")
            _init "BSSID" "PWD"
            ;;
        "1.2.3")
            _init "NWID" "WPAKEY"
            ;;
        *)
        echo "This script doesn't support your kext version."
    esac
fi


