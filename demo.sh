#!/bin/sh

function print_etc_hosts_instructions() {
    CN=$1
    echo "If you would like to run the package on the local machine you may need to add $CN to your hosts file. To do so run the following:"
    printf "printf \"\\\\n127.0.0.1 $CN\" | sudo tee -a /etc/hosts > /dev/null\n"
}

function compose_basename() {
    # docker-compose names containers, networks, etc. based on the basename of
    # the directory with _ and - removed. This function generates that
    # basename.
    echo $(basename $(pwd) | tr -d '_-')
}

function compose_network() {
    echo $(compose_basename)_default
}

function mac_enrollment_package() {
    PKGNAME=kolide-enroll
    PKGVERSION=1.0.0
    PKGID=co.kolide.osquery.enroll

    pkgroot="enrollment/mac/root"
    ENROLL_SECRET=$1
    CN=$(get_cn)

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
    secret=$(get_enroll_secret)
    case $platform in
    mac)
        mac_enrollment_package $secret
        ;;
    *)
        usage
        ;;
    esac
}

function add_docker_hosts() {
    CN=$(get_cn)

    total_hosts=$1
    ENROLL_SECRET=$(get_enroll_secret)

    mkdir -p docker_hosts
    cp server.crt docker_hosts/server.crt
    echo $ENROLL_SECRET > "docker_hosts/kolide_secret"
cat <<- EOF > docker_hosts/kolide.flags
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

    kolide_container_ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(compose_basename)_kolide_1)"

    KOLIDE_HOST_HOSTNAME="${CN}" \
        KOLIDE_HOST_IP="$kolide_container_ip" \
        docker-compose scale "ubuntu14-osquery=$total_hosts"
}

function get_cn() {
    docker run --rm -v $(pwd):/certs kolide/openssl x509 -noout -subject -in /certs/server.crt | sed -e 's/^subject.*CN=\([a-zA-Z0-9\.\-]*\).*$/\1/'
}

function upload_license() {
    license=$1
    out=$(docker run --rm -it --network=$(compose_network) --entrypoint curl kolide/openssl -k https://kolide:8412/api/v1/license --data \
           "{\"license\":\"$license\"}")
    if echo $out | grep -i error; then
        echo "Error: License upload failed: $out. Exiting." >&2
        exit 1
    fi
}

function perform_setup() {
    out=$(docker run --rm -it --network=$(compose_network) --entrypoint curl kolide/openssl -k https://kolide:8412/api/v1/setup --data \
           '{"kolide_server_url":"https://kolide:8412","org_info":{"org_name":"KolideQuick"},"admin":{"admin":true,"email":"quickstart@kolide.com","password":"admin123#","password_confirmation":"admin123#","username":"admin"}}')
    if echo $out | grep -i error; then
        echo "Error: License upload failed: $out. Exiting." >&2
        exit 1
    fi
}

function get_enroll_secret() {
    enroll_secret=$(docker run --rm -it --network=$(compose_network) mysql:5.7 mysql -h mysql -u kolide --password=kolide -e 'select osquery_enroll_secret from app_configs' --batch kolide | tail -1)
    if [ $? -ne 0 ] || [ -z $enroll_secret ]; then
        echo "Error: Could not retrieve enroll secret. Exiting." >&2
        exit 1
    fi
    echo $enroll_secret
}

function wait_kolide() {
    echo 'Waiting for Kolide server to accept connections...\c'
    for i in $(seq 1 50);
    do
        docker run --rm -it --network=$(compose_network) --entrypoint curl kolide/openssl -k -I https://kolide:8412 > /dev/null
        if [ $? -eq 0 ]; then
            echo
            return
        fi
        echo '.\c'
    done
    echo "Error: Kolide failed to start up. Exiting." >&2
    exit 1
}

function wait_mysql() {
    echo 'Waiting for MySQL to accept connections...\c'

    for i in $(seq 1 50);
    do
        docker run --rm -it --network=$(compose_network) mysql:5.7 mysqladmin ping -h mysql -u kolide --password=kolide > /dev/null
        if [ $? -eq 0 ]; then
            echo
            return
        fi
        echo '.\c'
    done

    echo "Error: MySQL failed to start up. Exiting." >&2
    exit 1
}

function up() {
    if [ "$1" != "simple" ]; then
        # copy user provided key and cert.
        key=$1
        cert=$2
        if [ ! -z $key ] && [ ! -z $cert ]; then
            cp "$key" server.key
            cp "$cert" server.crt
        fi
    fi

    # create a self signed cert if the user has not provided one.
    if [ ! -f server.key ]; then
        DEFAULT_CN='kolide'
        if [ "$1" != "simple" ]; then
            read -p "Enter CN for self-signed SSL certificate [default '$DEFAULT_CN']: " CN
        fi
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

    KOLIDE_HOST_HOSTNAME=unused \
        KOLIDE_HOST_IP=unused \
        docker-compose up -d kolide

    wait_mysql
    wait_kolide

    if [ "$1" == "simple" ]; then
        echo "Finalizing Kolide setup..."
        upload_license $2
        perform_setup
        echo "Setup complete. Please log in with username 'admin', password 'admin123#'"
    fi

    echo "Kolide server should now be accessible at https://127.0.0.1:8412 or https://${CN}:8412."
    echo "Note that a self-signed SSL certificate will generate a warning in the browser."
    echo "To allow other hosts to enroll, you may want to create a DNS entry mapping $CN to the IP of this host."
}

function down() {
    KOLIDE_HOST_HOSTNAME=unused \
        KOLIDE_HOST_IP=unused \
        docker-compose stop
}

function reset() {
    KOLIDE_HOST_HOSTNAME=unused \
        KOLIDE_HOST_IP=unused \
        docker-compose stop

    KOLIDE_HOST_HOSTNAME=unused \
        KOLIDE_HOST_IP=unused \
        docker-compose rm -f

    echo "Removing generated certs"
    rm -f server.key server.crt

    echo "Removing mysql data"
    rm -rf mysqldata
}

function usage() {
    echo "usage: ./demo.sh <subcommand>\n"
    echo "subcommands:"
    echo "    up simple <your license string>"
    echo "         Start the demo Kolide instance and dependencies, generating"
    echo "         self-signed certs and automating the entire setup process."
    echo "    up"
    echo "         Start the demo Kolide instance and dependencies, generating"
    echo "         self-signed certs".
    echo "    up <path to TLS key> <path to TLS certificate>"
    echo "         Start the demo Kolide instance and dependencies with the provided certs."
    echo "    down"
    echo "         Shut down the demo Kolide instance and dependencies."
    echo "    reset"
    echo "        Reset all keys, containers, and MySQL data."
    echo "    enroll <platform>"
    echo "        Create osquery configuration package for your platform."
    echo "        Supported platform values: mac"
    echo "    add_hosts <number of hosts>"
    echo "        Enroll demo osqueryd linux hosts."
}

docker pull kolide/kolide
docker pull kolide/openssl

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

    add_hosts)
        add_docker_hosts $2 $3
        ;;

    *)
        usage
        ;;
esac
