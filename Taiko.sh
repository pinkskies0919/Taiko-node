#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Taiko.sh"


function delete() {
    echo "正在卸载，请稍等······"
    cd simple-taiko-node
    docker compose --profile l2_execution_engine down
    docker stop simple-taiko-node-taiko_client_proposer-1 
    cd ..
    rm -rf simple-taiko-node
    read -p "按回车键返回主菜单"

    # 返回主菜单
    main_menu
}


# 节点安装功能
function install_node() {

# 更新系统包列表
sudo apt update

# 检查 Git 是否已安装
if ! command -v git &> /dev/null
then
    # 如果 Git 未安装，则进行安装
    echo "未检测到 Git，正在安装..."
    sudo apt install git -y
else
    # 如果 Git 已安装，则不做任何操作
    echo "Git 已安装。"
fi

# 克隆 Taiko 仓库
cd $HOME
git clone https://github.com/taikoxyz/simple-taiko-node.git

# 进入 Taiko 目录
cd simple-taiko-node

# 如果不存在.env文件，则从示例创建一个
if [ ! -f .env ]; then
  cp .env.sample .env
fi

# 提示用户输入环境变量的值
echo "回车默认"
read -p "请输入BlockPI holesky HTTP链接: " l1_endpoint_http
read -p "请输入BlockPI holesky WS链接: " l1_endpoint_ws
read -p "请输入Beacon Holskey RPC链接 [默认: https://burned-twilight-log.ethereum-holesky.quiknode.pro/]: " l1_beacon_http
l1_beacon_http=${l1_beacon_http:-'http://unstable.holesky.beacon-api.nimbus.team'}
read -p "请确认是否作为提议者（默认true）: " enable_proposer
enable_proposer=${enable_proposer:-'true'}
read -p "请确认是否关闭P2P同步（默认false）: " disable_p2p_sync
disable_p2p_sync=${disable_p2p_sync:-'false'}
read -p "请输入EVM钱包私钥(去0x): " l1_proposer_private_key
read -p "请输入EVM钱包地址: " l2_suggested_fee_recipient

# 检测并罗列未被占用的端口
function list_recommended_ports {
    local start_port=8000 # 可以根据需要调整起始搜索端口
    local needed_ports=7
    local count=0
    local ports=()

    while [ "$count" -lt "$needed_ports" ]; do
        if ! ss -tuln | grep -q ":$start_port " ; then
            ports+=($start_port)
            ((count++))
        fi
        ((start_port++))
    done

    echo "推荐的端口如下："
    for port in "${ports[@]}"; do
        echo -e "\033[0;32m$port\033[0m"
    done
}

# 使用推荐端口函数为端口配置
list_recommended_ports

# 提示用户输入端口配置，允许使用默认值
read -p "请输入L2执行引擎HTTP端口 [默认: 8547]: " port_l2_execution_engine_http
port_l2_execution_engine_http=${port_l2_execution_engine_http:-8547}

read -p "请输入L2执行引擎WS端口 [默认: 8548]: " port_l2_execution_engine_ws
port_l2_execution_engine_ws=${port_l2_execution_engine_ws:-8548}

read -p "请输入L2执行引擎Metrics端口 [默认: 6061]: " port_l2_execution_engine_metrics
port_l2_execution_engine_metrics=${port_l2_execution_engine_metrics:-6061}

read -p "请输入L2执行引擎P2P端口 [默认: 30306]: " port_l2_execution_engine_p2p
port_l2_execution_engine_p2p=${port_l2_execution_engine_p2p:-30306}

read -p "请输入证明者服务器端口 [默认: 9876]: " port_prover_server
port_prover_server=${port_prover_server:-9876}

read -p "请输入Prometheus端口 [默认: 9092]: " port_prometheus
port_prometheus=${port_prometheus:-9092}

read -p "请输入Grafana端口 [默认: 3001]: " port_grafana
port_grafana=${port_grafana:-3001}

# 将用户输入的值写入.env文件
sed -i "s|L1_ENDPOINT_HTTP=.*|L1_ENDPOINT_HTTP=${l1_endpoint_http}|" .env
sed -i "s|L1_ENDPOINT_WS=.*|L1_ENDPOINT_WS=${l1_endpoint_ws}|" .env
sed -i "s|L1_BEACON_HTTP=.*|L1_BEACON_HTTP=${l1_beacon_http}|" .env
sed -i "s|ENABLE_PROPOSER=.*|ENABLE_PROPOSER=${enable_proposer}|" .env
sed -i "s|L1_PROPOSER_PRIVATE_KEY=.*|L1_PROPOSER_PRIVATE_KEY=${l1_proposer_private_key}|" .env
sed -i "s|L2_SUGGESTED_FEE_RECIPIENT=.*|L2_SUGGESTED_FEE_RECIPIENT=${l2_suggested_fee_recipient}|" .env
sed -i "s|DISABLE_P2P_SYNC=.*|DISABLE_P2P_SYNC=${disable_p2p_sync}|" .env

# 更新.env文件中的端口配置
sed -i "s|PORT_L2_EXECUTION_ENGINE_HTTP=.*|PORT_L2_EXECUTION_ENGINE_HTTP=${port_l2_execution_engine_http}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_WS=.*|PORT_L2_EXECUTION_ENGINE_WS=${port_l2_execution_engine_ws}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_METRICS=.*|PORT_L2_EXECUTION_ENGINE_METRICS=${port_l2_execution_engine_metrics}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_P2P=.*|PORT_L2_EXECUTION_ENGINE_P2P=${port_l2_execution_engine_p2p}|" .env
sed -i "s|PORT_PROVER_SERVER=.*|PORT_PROVER_SERVER=${port_prover_server}|" .env
sed -i "s|PORT_PROMETHEUS=.*|PORT_PROMETHEUS=${port_prometheus}|" .env
sed -i "s|PORT_GRAFANA=.*|PORT_GRAFANA=${port_grafana}|" .env
sed -i "s|PROVER_ENDPOINTS=.*|PROVER_ENDPOINTS=http://hekla.stonemac65.xyz:9876|" .env
sed -i "s|BLOCK_PROPOSAL_FEE=.*|BLOCK_PROPOSAL_FEE=30|" .env

# 用户信息已配置完毕
echo "用户信息已配置完毕。"

# 升级所有已安装的包
sudo apt upgrade -y

# 安装基本组件
sudo apt install pkg-config curl build-essential libssl-dev libclang-dev ufw docker-compose-plugin -y

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null
then
    # 如果 Docker 未安装，则进行安装
    echo "未检测到 Docker，正在安装..."
    sudo apt-get install ca-certificates curl gnupg lsb-release

    # 添加 Docker 官方 GPG 密钥
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # 设置 Docker 仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 授权 Docker 文件
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    sudo apt-get update

    # 安装 Docker 最新版本
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
else
    echo "Docker 已安装。"
fi

    # 安装 Docker compose 最新版本
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
docker compose version

# 验证 Docker Engine 安装是否成功
sudo docker run hello-world

# 运行 Taiko 节点
docker compose --profile l2_execution_engine down
docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
docker compose --profile l2_execution_engine up -d


# 运行 Taiko proposer 节点
docker compose up taiko_client_proposer -d
# 获取公网 IP 地址
public_ip=$(curl -s ifconfig.me)

# 准备原始链接
original_url="LocalHost:${port_grafana}/d/L2ExecutionEngine/l2-execution-engine-overview?orgId=1&refresh=10s"

# 替换 LocalHost 为公网 IP 地址
updated_url=$(echo $original_url | sed "s/LocalHost/$public_ip/")

# 显示更新后的链接
echo "请保存以下链接，5分钟后进行访问：$updated_url"

}

# 查看节点日志
function check_service_status() {
    cd #HOME
    cd simple-taiko-node
    docker compose logs -f --tail 20
}

function change_rpc() {
cd #HOME
cd simple-taiko-node

rpc_list=("http://kenz-prover.hekla.kzvn.xyz:9876" "http://hekla.stonemac65.xyz:9876" "http://taiko.web3crypt.net:9876/" "http://198.244.201.79:9876")
rpc_string=""

for rpc in "${rpc_list[@]}"
do
  rpc_string="$rpc_string$rpc,"
done

rpc_string="${rpc_string%,}"

sed -i "s|PROVER_ENDPOINTS=.*|PROVER_ENDPOINTS=${rpc_string}|" .env

docker compose --profile l2_execution_engine down
docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
docker compose --profile l2_execution_engine up -d
docker compose up taiko_client_proposer -d
}

function check_service_status() {
    cd #HOME
    cd simple-taiko-node
    docker compose logs -f --tail 20
}

function restart() {
cd #HOME
cd simple-taiko-node

docker compose --profile l2_execution_engine down
docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
docker compose --profile l2_execution_engine up -d
docker compose up taiko_client_proposer -d
}

function change_blockpi() {
cd #HOME
cd simple-taiko-node

# 显示当前的 BlockPI holesky HTTP 链接和 BlockPI holesky WS 链接
echo "当前的BlockPI holesky HTTP链接: $(grep L1_ENDPOINT_HTTP .env | cut -d '=' -f2)"
echo "当前的BlockPI holesky WS链接: $(grep L1_ENDPOINT_WS .env | cut -d '=' -f2)"

read -p "请输入更换的BlockPI holesky HTTP链接 " l1_endpoint_http
read -p "请输入更换的BlockPI holesky WS链接: " l1_endpoint_ws

sed -i "s|L1_ENDPOINT_HTTP=.*|L1_ENDPOINT_HTTP=${l1_endpoint_http}|" .env
sed -i "s|L1_ENDPOINT_WS=.*|L1_ENDPOINT_WS=${l1_endpoint_ws}|" .env

docker compose --profile l2_execution_engine down
docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
docker compose --profile l2_execution_engine up -d
docker compose up taiko_client_proposer -d

echo "⠿ Network simple-taiko-node_default  Error报错可忽略"
}

function change_beaconrpc() {
cd $HOME/simple-taiko-node

echo "当前的Beacon Holskey RPC链接: $(grep L1_BEACON_HTTP .env | cut -d '=' -f2)"
read -p "请输入Beacon Holskey RPC链接 [默认: http://unstable.holesky.beacon-api.nimbus.team]: " l1_beacon_http
l1_beacon_http=${l1_beacon_http:-'http://unstable.holesky.beacon-api.nimbus.team'}

sed -i "s|L1_BEACON_HTTP=.*|L1_BEACON_HTTP=${l1_beacon_http}|" .env
docker compose --profile l2_execution_engine down
docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
docker compose --profile l2_execution_engine up -d
docker compose up taiko_client_proposer -d

echo "⠿ Network simple-taiko-node_default  Error报错可忽略"
}


function find_path() {
echo "正在查询Taiko节点路径，请稍等······(默认应为/root/simple-taiko-node)"
find / -xdev -name "simple-taiko-node" -type d
}

function add_bootnode() {
cd $HOME/simple-taiko-node

# 读取当前的BOOT_NODES参数
CURRENT_BOOT_NODES=$(grep -oP '^BOOT_NODES=\K.*' .env)

# 判断是否含有指定的enode
if [[ "$CURRENT_BOOT_NODES" =~ "enode://0b310c7dcfcf45ef32dde60fec274af88d52c7f0fb6a7e038b14f5f7bb7d72f3ab96a59328270532a871db988a0bcf57aa9258fa8a80e8e553a7bb5abd77c40d@167.235.249.45:30303,enode://500a10f3a8cfe00689eb9d41331605bf5e746625ac356c24235ff66145c2de454d869563a71efb3d2fb4bc1c1053b84d0ab6deb0a4155e7227188e1a8457b152@85.10.202.253:30303" ]]; then
  echo "BOOT_NODES参数中已包含指定的enode"
else
  # 在当前的BOOT_NODES参数后叠加指定的enode
  NEW_BOOT_NODES="${CURRENT_BOOT_NODES},${NEW_BOOT_NODES}"
  sed -i "s/^BOOT_NODES=.*/BOOT_NODES=${NEW_BOOT_NODES}/" .env
  echo "已成功添加指定的enode到BOOT_NODES参数中"
fi

}

# 主菜单
function main_menu() {
    clear
    echo "=====================专用脚本 盗者必究==========================="
    echo "需要测试网节点部署托管 技术指导 定制脚本 请联系Telegram :https://t.me/linzeusasa"
    echo "需要测试网节点部署托管 技术指导 定制脚本 请联系Wechat :llkkxx001"
    echo "从未安装过Taiko的vps请执行安装节点--更新prover rpc--查看节点日志"
    echo "安装过旧版本或者需要重装节点的vps请执行卸载旧版本--安装节点--更新prover rpc--查看节点日志"
    echo "请定期检查BlockPI rpc流量，不足时请执行更换BlockPI rpc"
    echo "请选择要执行的操作:"
    echo "1. 卸载旧版本"
    echo "2. 安装节点"
    echo "3. 更新prover rpc"
    echo "4. 查询节点日志"
    echo "5. 重启Taiko节点"
    echo "6. 更换BlockPI rpc"
    echo "7. 更换Beacon rpc"
    echo "8. 查询Taiko节点是否安装"
    echo "9. 加速区块同步节点"
    read -p "请输入选项（1-9）: " OPTION

    case $OPTION in
    1) delete ;;
    2) install_node ;;
    3) change_rpc ;;
    4) check_service_status ;;
    5) restart ;;
    6) change_blockpi ;;
    7) change_beaconrpc ;;
    8) find_path ;;
    9) add_bootnode ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
