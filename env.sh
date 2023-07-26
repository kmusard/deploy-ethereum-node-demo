# shellcheck disable=SC2148
check_ip () {
    if ! [ -f ./terraform/ethereum-mainnet-node/ip.txt ]; then
        echo "No IP file found. Run 'vcc-tf apply -auto-approve' first."
        return 1
    fi
    IP=$(cat ./terraform/ethereum-mainnet-node/ip.txt)
    echo "${IP}"
}

vcc_build () {
    docker run --rm -i -t \
        -v ./src:/src \
        golang:1.20 \
        /bin/sh -c "cd /src && go mod download && go mod verify && go build -o peers peers.go"
}
alias vcc-build='vcc_build'

vcc_endpoints () {
    IP=$(check_ip)
    echo "Raw IP: ${IP}"
    echo "Grafana: http://${IP}:3000"
    echo "Prometheus: http://${IP}:9090"
    echo "Prysm: http://${IP}:3500"
}
alias vcc-endpoints='vcc_endpoints'

vcc_logs () {
    IP=$(check_ip)
    ssh \
        -i ethereum-mainnet-node.pem \
        -o StrictHostKeyChecking=no \
        ubuntu@"${IP}" \
        "sudo journalctl -u geth -u grafana-server -u node_exporter -u prometheus -u prysm -f"
}
alias vcc-logs='vcc_logs'

vcc_peers () {
    IP=$(check_ip)
    if ! [ -f ./src/peers ]; then
        echo "No peers binary found. Run 'vcc-build' first."
        return 1
    fi
    ./src/peers -endpoint=http://"${IP}":3500
}
alias vcc-peers='vcc_peers'

vcc_ssh_connect () {
    IP=$(check_ip)
    ssh \
        -i ethereum-mainnet-node.pem \
        -o StrictHostKeyChecking=no \
        ubuntu@"${IP}"
}
alias vcc-ssh='vcc_ssh_connect'

vcc_tf () {
    docker run --rm -i -t \
        -e AWS_ACCESS_KEY_ID=AKIA4QHXFR5WKLP3SY5D \
        -e AWS_SECRET_ACCESS_KEY=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 \
        -e AWS_DEFAULT_REGION=us-east-1 \
        -v ./terraform/ethereum-mainnet-node:/tf \
        hashicorp/terraform:1.5.3 -chdir=/tf "$@"
}
alias vcc-tf='vcc_tf'
