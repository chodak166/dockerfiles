#!/bin/bash

#TODO: refactor
#TODO: add colored output
#TODO: test re-run
#TODO: get rid of batch mode?
#TODO: add package remove helper

function main {

    if [ ! -f /var/apt_init_done ]; then
	
	initAuthorizedKeys
	initGpgKey
	initNginx
	initReprepro
	initWeb
	initHelpers

    fi

    touch /var/apt_init_done
    initServices
}

function initAuthorizedKeys {

    AUTHORIZED_KEYS=/home/debian/.ssh/authorized_keys
    AUTHORIZED_KEYS_MOUNT=$(echo "/srv$AUTHORIZED_KEYS")
    if [ ! -f $AUTHORIZED_KEYS_MOUNT ]; then
	SSH_KEY_DIR=$(dirname $AUTHORIZED_KEYS_MOUNT)
	echo "---SSH-KEYS---"
	echo "Warning: No authorized_keys file found!"
	echo " Please provide one to: \$CONFIG_DIR$AUTHORIZED_KEYS"
	mkdir -p $SSH_KEY_DIR
	echo ""
    else
	ln -sfv $AUTHORIZED_KEYS_MOUNT $AUTHORIZED_KEYS
    fi
    
}

function initGpgKey {

    GPG_PUBLIC=/home/debian/.gnupg/pubring.gpg
    GPG_PUBLIC_MOUNT=$(echo "/srv$GPG_PUBLIC")

    GPG_SECRET=/home/debian/.gnupg/secring.gpg
    GPG_SECRET_MOUNT=$(echo "/srv$GPG_SECRET")

    if [ ! -f $GPG_PUBLIC_MOUNT ] || [ ! -f $GPG_SECRET_MOUNT ]; then
	GPG_KEY_DIR=$(dirname $GPG_PUBLIC_MOUNT)
	echo "---GPG-KEYS---"
	echo "Warning: No GPG keys found!"
	echo " Please provide a pair to: \$CONFIG_DIR$GPG_KEY_DIR"
	mkdir -p $GPG_KEY_DIR
	echo ""

	echo -e "Auto: Generating keys \c"
	if [[ -z "$KEY_REAL_NAME" ]] || [[ -z "$KEY_COMMENT" ]] || [[ -z "$KEY_EMAIL" ]]; then
            echo "in interactive mode;"
            echo "--------------------------------------------------------------------------------"
            sudo -u debian gpg --gen-key
	else
            echo "in batch-mode;"
            echo "--------------------------------------------------------------------------------"

            BATCH_FILE=/home/debian/batch_cmds

            cat /templates/batch_cmds > $BATCH_FILE
            echo "Name-Real: $KEY_REAL_NAME" >> $BATCH_FILE
            echo "Name-Comment: $KEY_COMMENT" >> $BATCH_FILE
            echo "Name-Email: $KEY_EMAIL" >> $BATCH_FILE
            echo "%commit" >> $BATCH_FILE

            sudo -u debian gpg --batch --gen-key $BATCH_FILE
	fi

	echo "--------------------------------------------------------------------------------"
	echo "Key generation done!"
	echo ""

	cp $GPG_PUBLIC $GPG_PUBLIC_MOUNT
	cp $GPG_SECRET $GPG_SECRET_MOUNT
    else
	cp $GPG_PUBLIC_MOUNT $GPG_PUBLIC
	cp $GPG_SECRET_MOUNT $GPG_SECRET
    fi

    sudo -u debian gpg --list-keys > /dev/null 2> /dev/null

    KEY_ID=$(sudo -u debian gpg --list-keys | tail -2 | sed "s/.*\/\(.*\)\s.*/\1/g")
    echo "KEY_ID: $KEY_ID"
    
}

function initNginx {
    
    NGINX_CONFIGURATION=/etc/nginx/sites-enabled/reprepro-repository
    NGINX_CONFIGURATION_MOUNT=$(echo "/srv$NGINX_CONFIGURATION")
    if [ ! -f $NGINX_CONFIGURATION_MOUNT ]; then
	NGINX_DIR=$(dirname $NGINX_CONFIGURATION_MOUNT)
	echo "---NGINX---"
	echo "Warning: No nginx configuration file found"
	echo " Please provide one to: \$CONFIG_DIR$NGINX_CONFIGURATION"
	mkdir -p $NGINX_DIR
	echo ""

	echo -e "Auto: Generating configuration"

	cp -v /templates/reprepro-repository $NGINX_CONFIGURATION_MOUNT

	echo "Configuration file created!"
	echo ""
    else
	HOST_ADDR=$(cat $NGINX_CONFIGURATION_MOUNT | grep "server_name" | sed "s/\s*server_name\s\(.*\);/\1/g")
    fi
    cp -v $NGINX_CONFIGURATION_MOUNT $NGINX_CONFIGURATION
    rm /etc/nginx/sites-enabled/default

    if [[ -z "$HOST_ADDR" ]]; then
        echo -e "Host address or domain: \c"
        read HOST_ADDR
        echo ""
    fi

    echo "HOST_ADDR: $HOST_ADDR"

    if [[ -z "$HOST_PORT" ]]; then
        echo -e "External (forwarded) docker port: \c"
        read HOST_PORT
        echo ""
    fi

    echo "HOST_PORT: $HOST_PORT"
    
}

function initReprepro {

    REPREPRO_DISTRIBUTIONS=/var/www/repos/apt/debian/conf/distributions
    REPREPRO_DISTRIBUTIONS_MOUNT=$(echo "/srv$REPREPRO_DISTRIBUTIONS")
    if [ ! -f $REPREPRO_DISTRIBUTIONS_MOUNT ]; then
	REPREPRO_DIR=$(dirname $REPREPRO_DISTRIBUTIONS_MOUNT)
	echo "---REPREPRO---"
	echo "Warning: No reprepro distributions configuration file found"
	echo " Please provide one to: \$CONFIG_DIR$REPREPRO_DISTRIBUTIONS"
	mkdir -p $(dirname $REPREPRO_DISTRIBUTIONS)
	mkdir -p $REPREPRO_DIR
	echo ""

	echo -e "Auto: Generating configuration \c"
	if [[ -z "$PROJECT_NAME" ]]; then
            echo "in interactive mode;"
            echo -e "Project Name: \c"
            read PROJECT_NAME
            echo ""
	else
            echo "in batch-mode."
	fi

	if [[ -z "$CODE_NAME" ]]; then
            echo -e "Codename (wheezy/jessie/other): \c"
            read CODE_NAME
            echo ""
	fi

	cat /templates/distributions | sed "s/!!!PROJECT_NAME_HERE!!!/$PROJECT_NAME/g" | sed "s/!!!CODE_NAME_HERE!!!/$CODE_NAME/g" | sed "s/!!!KEY_ID_HERE!!!/$KEY_ID/g" > $REPREPRO_DISTRIBUTIONS_MOUNT

	echo "Configuration file created!"
	echo ""
    else
	PROJECT_NAME=$(cat $REPREPRO_DISTRIBUTIONS_MOUNT | grep "Origin" | sed "s/Origin:\s\(.*\)/\1/g")
	CODE_NAME=$(cat $REPREPRO_DISTRIBUTIONS_MOUNT | grep "Codename" | sed "s/Codename:\s\(.*\)/\1/g")
    fi
    cp -v $REPREPRO_DISTRIBUTIONS_MOUNT $REPREPRO_DISTRIBUTIONS 

    #echo "PROJECT_NAME: $PROJECT_NAME"
    #echo "CODE_NAME: $CODE_NAME"

    # Options
    REPREPRO_OPTIONS=/var/www/repos/apt/debian/conf/options
    REPREPRO_OPTIONS_MOUNT=$(echo "/srv$REPREPRO_OPTIONS")
    if [ ! -f $REPREPRO_OPTIONS_MOUNT ]; then
	REPREPRO_DIR=$(dirname $REPREPRO_DISTRIBUTIONS_MOUNT)
	echo "---REPREPRO---"
	echo "Warning: No reprepro distributions configuration file found"
	echo " Please provide one to: \$CONFIG_DIR$REPREPRO_OPTIONS"
	mkdir -p $REPREPRO_DIR
	echo ""

	echo "Auto: Generating configuration; default"

	cat /templates/options > $REPREPRO_OPTIONS_MOUNT

	echo "Configuration file created!"
	echo ""
    fi
    cp -v $REPREPRO_OPTIONS_MOUNT $REPREPRO_OPTIONS

    # Override
    REPREPRO_OVERRIDE=$(echo "/var/www/repos/apt/debian/conf/override.$CODE_NAME")
    REPREPRO_OVERRIDE_MOUNT=$(echo "/srv$REPREPRO_OPTIONS")
    if [ ! -f $REPREPRO_OVERRIDE_MOUNT ]; then
	REPREPRO_DIR=$(dirname $REPREPRO_OVERRIDE_MOUNT)
	echo "---REPREPRO---"
	echo "Warning: No reprepro distributions configuration file found"
	echo " Please provide one to: \$CONFIG_DIR$REPREPRO_OVERRIDE"
	mkdir -p $REPREPRO_DIR
	echo ""

	echo "Auto: Generating configuration; default"

	cat /templates/override > $REPREPRO_OVERRIDE_MOUNT

	echo "Configuration file created!"
	echo ""
    fi
    cp -v $REPREPRO_OVERRIDE_MOUNT $REPREPRO_OVERRIDE
    
}

function initWeb {

    # Pubish gpg key
    cd /home/debian/
    sudo -u debian gpg --armor --output public.gpg.key --export $KEY_ID
    mv public.gpg.key /var/www/repos/apt/debian/public.gpg.key
    chown -R debian:debian /var/www/repos

    # Make index.html
    cat /templates/index.html \
	| sed "s/!!!HOST_NAME_HERE!!!/$HOST_ADDR/g" \
	| sed "s/!!!HOST_PORT_HERE!!!/$HOST_PORT/g" \
	| sed "s/!!!CODE_NAME_HERE!!!/$CODE_NAME/g" \
	      > /var/www/repos/apt/debian/index.html
    
}

function initHelpers {
    
    # set user password if needed
    echo "Setup 'debian' user password? (y/N): "
    read c
    if [ "$c" == "y" ]
    then
	passwd debian
    fi

    # generate helper scripts configs
    echo "INCOMING_DIR=/apt
REPO_BASE_DIR=/var/www/repos/apt/debian
PROJECT_NAME=$PROJECT_NAME
" > /etc/repo.config

    # generate incoming structure for initial codename
    echo -e "\nCreating incoming structure for codename $CODE_NAME\n"
    mkdir -pv /apt/$CODE_NAME/main/amd64
    mkdir -pv /apt/$CODE_NAME/main/i386
    mkdir -pv /apt/$CODE_NAME/main/armhf
    mkdir -pv /apt/$CODE_NAME/main/multiarc
    chown -R debian:debian /apt
}

function initServices {
    echo -e "\nUse Ctrl+P, Ctrl+Q to detach\n"
    
    echo -e "Running sshd and nginx\n"
    # Start up the webserver
    /usr/sbin/nginx
    # ... and the ssh daemon
    /usr/sbin/sshd -D
}

main $@
