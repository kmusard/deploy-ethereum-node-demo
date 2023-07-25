# shellcheck disable=SC2148
eth_demo_check_ip () {
    if ! [ -f ./terraform/ethereum-mainnet-node/ip.txt ]; then
        echo "No IP file found. Run 'eth-demo-tf apply -auto-approve' first."
        return 1
    fi
    IP=$(cat ./terraform/ethereum-mainnet-node/ip.txt)
    echo "${IP}"
}
alias eth-demo-check-ip='eth_demo_check_ip'

eth_demo_build () {
    docker run --rm -i -t \
        -v ./src:/src \
        golang:1.20 \
        /bin/sh -c "cd /src && go mod download && go mod verify && go build -o peers peers.go"
}
alias eth-demo-build='eth_demo_build'

eth_demo_create_key_pair () {
    docker run --rm -i -t \
        -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
        -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
        -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} \
        -v ./:/key-pair \
        amazon/aws-cli:latest \
        /bin/sh -c "aws ec2 create-key-pair --key-name eth-node-demo --key-type rsa --key-format pem --query 'KeyMaterial' --output text"
}
alias eth-demo-create-key-pair='eth_demo_create_key_pair'

eth_demo_endpoints () {
    IP=$(check_ip)
    echo "Raw IP: ${IP}"
    echo "Grafana: http://${IP}:3000"
    echo "Prometheus: http://${IP}:9090"
    echo "Prysm: http://${IP}:3500"
}
alias eth-demo-endpoints='eth_demo_endpoints'

eth_demo_logs () {
    IP=$(check_ip)
    ssh \
        -i ethereum-mainnet-node.pem \
        -o StrictHostKeyChecking=no \
        ubuntu@"${IP}" \
        "sudo journalctl -u geth -u grafana-server -u node_exporter -u prometheus -u prysm -f"
}
alias eth-demo-logs='eth_demo_logs'

eth_demo_peers () {
    IP=$(check_ip)
    if ! [ -f ./src/peers ]; then
        echo "No peers binary found. Run 'eth-demo-build' first."
        return 1
    fi
    ./src/peers -endpoint=http://"${IP}":3500
}
alias eth-demo-peers='eth_demo_peers'

eth_demo_ssh_connect () {
    IP=$(check_ip)
    ssh \
        -i ethereum-mainnet-node.pem \
        -o StrictHostKeyChecking=no \
        ubuntu@"${IP}"
}
alias eth-demo-ssh='eth_demo_ssh_connect'

eth_demo_tf () {
    if ! [ -f ./eth-node-demo.pem ]; then
        eth_demo_create_key_pair
    fi
    docker run --rm -i -t \
        -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
        -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
        -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} \
        -v ./terraform/ethereum-mainnet-node:/tf \
        hashicorp/terraform:1.5.3 -chdir=/tf "$@"
}
alias eth-demo-tf='eth_demo_tf'
