#!/bin/sh

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
    echo "Note that the self-signed SSL certificate will generate a warning in the browser."
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
    echo "    up    Bring up the demo Kolide instance and dependencies"
    echo "    down  Shut down the demo Kolide instance and dependencies"
    echo "    reset Reset all keys, containers, and MySQL data"
}

case $1 in
    up)
        up
        ;;

    down)
        down
        ;;

    reset)
        reset
        ;;
    *)
        usage
        ;;
esac
