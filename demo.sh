#!/bin/sh

function print_etc_hosts_instructions() {
    CN=$1
    echo "If you would like to run the package on the local machine you may need to add $CN to your hosts file. To do so run the following:"
    printf "printf \"\\\\n127.0.0.1 $CN\" | sudo tee -a /etc/hosts > /dev/null\n"
}

function mac_enrollment_package() {
    PKGNAME=kolide-enroll
    PKGVERSION=1.0.0
    PKGID=co.kolide.osquery.enroll

    pkgroot="enrollment/mac/root"
    ENROLL_SECRET=$1
    CN=$(get_cn)
    if [ -z $ENROLL_SECRET ]; then
        echo "Please provide an enroll secret to be used by osquery."
        echo "You can find find out the enroll secret by going to https://${CN}:8412/hosts/manage"
        echo "and clicking Add Hosts on the top right side of the page."
        echo "./demo.sh enroll mac MY_ENROLL_SECRET"
        exit 1
    fi

    mkdir -p enrollment/mac/root/etc/osquery
    cat <<- EOF > enrollment/mac/root/etc/osquery/kolide.flags
--force=true
--host_identifier=hostname
--verbose=true
--debug
--tls_dump=true

--tls_hostname=${CN}:8412
--tls_server_certs=/etc/osquery/kolide.crt
--enroll_secret_path=/etc/osquery/kolide_secret

--enroll_tls_endpoint=/api/v1/osquery/enroll

--config_plugin=tls
--config_tls_endpoint=/api/v1/osquery/config
--config_tls_refresh=10

--disable_distributed=false
--distributed_plugin=tls
--distributed_interval=10
--distributed_tls_max_attempts=3
--distributed_tls_read_endpoint=/api/v1/osquery/distributed/read
--distributed_tls_write_endpoint=/api/v1/osquery/distributed/write

--logger_plugin=tls
--logger_tls_endpoint=/api/v1/osquery/log
--logger_tls_period=10
EOF

    mkdir -p "$pkgroot/etc/osquery"
    mkdir -p out
    echo $ENROLL_SECRET > "$pkgroot/etc/osquery/kolide_secret"
    cp server.crt "$pkgroot/etc/osquery/kolide.crt"
	pkgbuild --root $pkgroot \
        --scripts "enrollment/mac/scripts" \
        --identifier ${PKGID} \
        --version ${PKGVERSION} out/${PKGNAME}-${PKGVERSION}.pkg

    print_etc_hosts_instructions $CN
}

function enrollment() {
    platform="$1"
    secret="$2"
    case $platform in
    mac)
        mac_enrollment_package $secret
        ;;
    *)
        usage
        ;;
    esac
}

function get_cn() {
    docker run -v $(pwd):/certs kolide/openssl x509 -noout -subject -in /certs/server.crt | sed -e 's/^subject.*CN=\([a-zA-Z0-9\.\-]*\).*$/\1/'
}

function wait_mysql() {
    echo 'Waiting for MySQL to accept connections...\c'
    network=$(basename $(pwd) | tr -d '_-')_default

    for i in $(seq 1 50);
    do
        docker run -it --network=$network mysql:5.7 mysqladmin ping -h mysql -u kolide --password=kolide > /dev/null \
            && break
        echo '.\c'
    done

    echo
}

function up() {
    # copy user provided key and cert.
    key=$1
    cert=$2
    if [ ! -z $key ] && [ ! -z $cert ]; then
        cp "$key" server.key
        cp "$cert" server.crt
    fi

    # create a self signed cert if the user has not provided one.
    if [ ! -f server.key ]; then
        DEFAULT_CN='localhost'
        read -p "Enter CN for self-signed SSL certificate [default '$DEFAULT_CN']: " CN
        CN=${CN:-$DEFAULT_CN}

        # Create self-signed SSL cert with no passphrase
        docker run --rm -v $(pwd):/certs kolide/openssl genrsa -out /certs/server.key 2048
        docker run --rm -v $(pwd):/certs kolide/openssl rsa -in /certs/server.key -out /certs/server.key
        docker run --rm -v $(pwd):/certs kolide/openssl req -sha256 -new -key /certs/server.key -out /certs/server.csr -subj "/CN=$CN"
        docker run --rm -v $(pwd):/certs kolide/openssl x509 -req -sha256 -days 365 -in /certs/server.csr -signkey /certs/server.key -out /certs/server.crt
        rm server.csr
    else
        CN=$(get_cn)
    fi

    docker-compose up -d
    wait_mysql

    echo "Kolide server should now be accessible at https://127.0.0.1:8412 or https://${CN}:8412."
    echo "Note that a self-signed SSL certificate will generate a warning in the browser."
    echo "To allow other hosts to enroll, you may want to create a DNS entry mapping $CN to the IP of this host."
}

function down() {
    docker-compose stop
}

function reset() {
    docker-compose stop && docker-compose rm -f
    echo "Removing generated certs"
    rm server.key server.crt
    echo "Removing mysql data"
    rm -r mysqldata
}

function usage() {
    echo "usage: ./demo.sh <subcommand>\n"
    echo "subcommands:"
    echo "    up [path to TLS key] [path to TLS certificate]"
    echo "    up    Bring up the demo Kolide instance and dependencies"
    echo "    up    up will generate a self signed certificate by default"
    echo "    down  Shut down the demo Kolide instance and dependencies"
    echo "    reset Reset all keys, containers, and MySQL data"
    echo "    enroll <platform> <secret> create osquery configuration package for your platform"
    echo "    enroll supported platform values: mac"
}

case $1 in
    up)
        up $2 $3
        ;;

    down)
        down
        ;;

    enroll)
        enrollment $2 $3
        ;;

    reset)
        reset
        ;;
    *)
        usage
        ;;
esac
