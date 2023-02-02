# Clear terminal
clear

# Color variable
RESET_CL="\033[0m"
BLACK='\033[1;30m'        # Black
RED='\033[1;31m'          # Red
GREEN='\033[0;32m'        # Green
YELLOW='\033[0;33m'       # Yellow
BLUE='\033[0;34m'         # Blue
PURPLE='\033[0;35m'       # Purple
CYAN='\033[0;36m'         # Cyan
WHITE='\033[0;37m'        # White

# Folder env
FOLDER_ENV="~/Projects/docker-env"

# Folder mount
FOLDER_MOUNT="/mnt"

# Service version
GATEWAY_VERSION="v1.0.3"
AZURE_VERSION="v1.0.2"
ADMIN_VERSION="v1.0.2"
USER_VERSION="v1.0.4"
PROJECT_SYSTEM_VERSION="latest"
TAS_VERSION="v1.1.5"
B_CONTRACT_VERSION="v2.0.7"
E_BIDDING_VERSION="v1.1.5"
SAP_VERSION="latest"
# APPROVAL_VERSION="v1.1.0"
APPROVAL_VERSION="dev"

# Create docker network
CmdNetwork="docker network create -d bridge emis-app"

# Create postgresql database container
CmdDatabase="docker run -d --network emis-app --name postgres -p 5432:5432 --hostname postgres -e POSTGRES_PASSWORD=Ecoba@2020 -e PGDATA=/var/lib/postgresql/data/pgdata -v ~/.docker_data/postgres:/var/lib/postgresql/data postgres"

# Create consul container
CmdConsul="docker run -d \
    --name consul \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env \
    -p 8500:8500 \
    --hostname consul \
    -v ~/.docker_data/consul:/consul/data \
    consul \
    agent -server \
    -ui -bind 0.0.0.0 -client 0.0.0.0 \
    -bootstrap -bootstrap-expect 1"

# Service docker commands
CmdGateway="docker run -d --name api-gateway \
    --network emis-app -p 4000:80 \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/api-gateway.env \
    ecobavn/api-gateway:$GATEWAY_VERSION"

CmdAzure="docker run -d --name azure-identity \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/azure-identity.env \
ecobavn/azure-identity:$AZURE_VERSION"

CmdAdmin="docker run -d --name admin \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/admin.env \
    ecobavn/admin:$ADMIN_VERSION"

CmdUser="docker run -d --name user \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/user.env \
    ecobavn/user:$USER_VERSION"

CmdProject="docker run -d --name project-system \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/project-system.env \
    ecobavn/project-system:$PROJECT_SYSTEM_VERSION"

CmdTas="docker run -d --name tas \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/tas.env \
    ecobavn/tas:$TAS_VERSION"

CmdBContract="docker run -d --name b-contract \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/b-contract.env \
    -v $FOLDER_MOUNT/Shared:/b-contract \
    ecobavn/b-contract:$B_CONTRACT_VERSION"

CmdEBidding="docker run -d --name bidding \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/bidding.env \
    -v $FOLDER_MOUNT/Shared:/e-bidding \
    ecobavn/bidding:$E_BIDDING_VERSION"

CmdSap="docker run -d --name sap \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/sap-help-desk.env \
    -v $FOLDER_MOUNT/Shared:/mnt \
    ecobavn/sap-help-desk:$SAP_VERSION"

CmdApproval="docker run -d --name approval-3 \
    --network emis-app \
    --env-file $FOLDER_ENV/global.env --env-file $FOLDER_ENV/approval3.env \
    ecobavn/approval:$APPROVAL_VERSION"

function try()
{
    [[ $- = *e* ]]; SAVED_OPT_E=$?
    set +e
}

function throw()
{
    exit $1
}

function catch()
{
    export ex_code=$?
    (( $SAVED_OPT_E )) && set +e
    return $ex_code
}

function throwErrors()
{
    set -e
}

function ignoreErrors()
{
    set +e
}

startService() {
    echo -e "${BLUE}- Starting $1 service${RESET_CL}"
    output=$(eval "$2")
    echo -e "${GREEN}- $1 service version $3 start in container ID $output ${RESET_CL} \n"
}

function select_option {

    # little helpers for terminal print control and key input
    ESC=$(printf "\033")
    cursor_blink_on() { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to() { printf "$ESC[$1;${2:-1}H"; }
    print_option() { printf "   $1 "; }
    print_selected() { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row() {
        IFS=';' read -sdR -p $'\E[6n' ROW COL
        echo ${ROW#*[}
    }
    key_input() {
        read -s -n3 key 2>/dev/null >&2
        if [[ $key = $ESC[A ]]; then echo up; fi
        if [[ $key = $ESC[B ]]; then echo down; fi
        if [[ $key = "" ]]; then echo enter; fi
    }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=$(get_cursor_row)
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case $(key_input) in
        enter) break ;;
        up)
            ((selected--))
            if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi
            ;;
        down)
            ((selected++))
            if [ $selected -ge $# ]; then selected=0; fi
            ;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

function select_opt {
    select_option "$@" 1>&2
    local result=$?
    echo $result
    return $result
}

IS_LOOP=true

options=("Create network" "Database" "Start consul" "Api Gateway" "Azure Identity service" "Admin service" "User service" "Project system service" "Tas service" "B Contract service" "E Bidding service" "Sap Help Desk service" "Approval service" "Test" "Quit")
while $IS_LOOP
do
    echo -e "${RED}Select one option using up/down keys and enter to confirm:${RESET_CL}"
    case `select_opt "${options[@]}"` in
    0) $CmdNetwork ;;
    1) startService "Database" "$CmdDatabase" "1.0" ;;
    2) startService "Consul" "$CmdConsul" "1.0" ;;
    3) startService "Api Gateway" "$CmdGateway" "$GATEWAY_VERSION" ;;
    4) startService "Azure Identity" "$CmdAzure" "$AZURE_VERSION" ;;
    5) startService "Admin" "$CmdAdmin" "$ADMIN_VERSION" ;;
    6) startService "User" "$CmdUser" "$USER_VERSION" ;;
    7) startService "Project System" "$CmdProject" "$PROJECT_SYSTEM_VERSION";;
    8) startService "Tas" "$CmdTas" "$TAS_VERSION" ;;
    9) startService "B Contract" "$CmdBContract" "$B_CONTRACT_VERSION" ;;
    10) startService "E Bidding" "$CmdEBidding" "$E_BIDDING_VERSION" ;;
    11) startService "Sap Help Desk" "$CmdSap" "$SAP_VERSION" ;;
    12) startService "Approval" "$CmdApproval" "$APPROVAL_VERSION" ;;
    13) echo -e "${GREEN}Hehehe${RESET_CL}";;
    14) exit 1;;
    *) echo "selected ${options[$?]} index $?";;
    esac
done
