#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Taiko.sh"

# 查询信息
function query_info() {
        clear
        echo "请选择要执行的操作:"
        echo "1. 查询节点日志"
        echo "2. 查询Taiko节点是否安装"
        echo "3. 查询钱包地址"
        echo "4. 记录配置信息"
        echo "5. 返回主菜单"
        read -p "请输入选项（1-5）: " OPTION

        case $OPTION in
            1) check_service_status ;;
            2) find_path ;;
            3) query_wallet_address ;;
            4) record ;;
            5) main_menu ;;
            *) echo "无效选项。" ;;
        esac
}

# 记录配置信息功能
function record() {
    # 设置.env文件路径
    env_file="/root/simple-taiko-node/.env"
    # 从.env文件中提取参数值并记录到record.txt文件中
    record_file="/root/record.txt"
    {
        echo "L1_ENDPOINT_HTTP=$(grep "L1_ENDPOINT_HTTP=" "$env_file" | cut -d '=' -f 2)"
        echo "L1_ENDPOINT_WS=$(grep "L1_ENDPOINT_WS=" "$env_file" | cut -d '=' -f 2)"
        echo "L1_PROPOSER_PRIVATE_KEY=$(grep "L1_PROPOSER_PRIVATE_KEY=" "$env_file" | cut -d '=' -f 2)"
        echo "L2_SUGGESTED_FEE_RECIPIENT=$(grep "L2_SUGGESTED_FEE_RECIPIENT=" "$env_file" | cut -d '=' -f 2)"
    } > "$record_file"

    # 检查记录是否成功
    if [ -s "$record_file" ]; then
        echo "成功记录到$record_file"
    else
        echo "记录失败"
    fi

    read -p "按回车键返回主菜单"

    # 返回主菜单
    main_menu
}


# 查询钱包地址
function query_wallet_address() {
    cd $HOME/simple-taiko-node
    wallet_address=$(grep '^L2_SUGGESTED_FEE_RECIPIENT' .env | cut -d '=' -f2)
    if [ -n "$wallet_address" ]; then
        echo "钱包地址为: $wallet_address"
    else
        echo "无法找到钱包地址。"
    fi
    read -p "按回车键返回主菜单" 
    main_menu
}


# 定义更换参数信息函数
function change_parameters_info() {
        clear
        echo "请选择要执行的操作:"
        echo "1. 更新prover rpc"
        echo "2. 更换BlockPI rpc"
        echo "3. 更换Beacon rpc"
        echo "4. 加速区块同步节点"
        echo "5. 设置gasfee"
        echo "6. 移除prover和TX_GAS_LIMIT"
        echo "7. 仅移除TX_GAS_LIMIT"
        echo "8. 返回主菜单"
        read -p "请输入选项（1-8）: " OPTION

        case $OPTION in
            1) change_rpc ;;
            2) change_blockpi ;;
            3) change_beaconrpc ;;
            4) add_bootnode ;;
            5) set_fee ;;
            6) remove ;;
            7) remove1 ;;
            8) main_menu ;;
            *) echo "无效选项。" ;;
        esac
}

function remove() {
    cd $HOME/simple-taiko-node
    sed -i 's|PROVER_ENDPOINTS=.*|PROVER_ENDPOINTS=http://taiko-a7-prover.zkpool.io|' .env
    sed -i 's|TX_GAS_LIMIT=.*|TX_GAS_LIMIT=|' .env

    echo "参数更新成功"

    docker compose --profile l2_execution_engine down
    docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
    docker compose --profile l2_execution_engine up -d
    docker compose --profile proposer up -d
    
}

function remove1() {
    cd $HOME/simple-taiko-node
    sed -i 's|TX_GAS_LIMIT=.*|TX_GAS_LIMIT=|' .env
    echo "参数更新成功"

    docker compose --profile l2_execution_engine down
    docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
    docker compose --profile l2_execution_engine up -d
    docker compose --profile proposer up -d
    
}

function delete() {
        clear
        echo "请选择要执行的操作:"
        echo "1. 常规卸载"
        echo "2. 彻底卸载(清除所有容器，多节点慎用)"
        echo "3. 返回主菜单"
        read -p "请输入选项（1-3）: " OPTION

        case $OPTION in
            1) uninstall_regular ;;
            2) uninstall_full ;;
            3) main_menu ;;
            *) echo "无效选项。" ;;
        esac
}


# 常规卸载功能
function uninstall_regular() {
    echo "正在卸载，请稍等······"
    cd simple-taiko-node
    docker compose --profile l2_execution_engine down
    docker stop simple-taiko-node-taiko_client_proposer-1 
    cd ..
    rm -rf simple-taiko-node
    read -p "按回车键返回"
}
# 彻底卸载功能
function uninstall_full() {
    echo "正在彻底卸载，请稍等······"
    cd simple-taiko-node
    docker stop $(docker ps -a -q)
    docker rm $(docker ps -a -q)
    docker rmi $(docker images -q)
    docker network prune
    docker volume prune
    docker system prune -a
    cd ..
    rm -rf simple-taiko-node
    read -p "按回车键返回主菜单"
}

function install_node1() {

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
read -p "请输入EVM钱包私钥(去0x): " l1_proposer_private_key
read -p "请输入EVM钱包地址: " l2_suggested_fee_recipient
l1_beacon_http="http://95.217.74.216:5052"
enable_proposer="true"
disable_p2p_sync="false"

# 设置默认端口值
port_l2_execution_engine_http=8547
port_l2_execution_engine_ws=8548
port_l2_execution_engine_metrics=6061
port_l2_execution_engine_p2p=30306
port_prover_server=9876
port_prometheus=9092
port_grafana=3001

# 将用户输入的值写入.env文件
sed -i "s|L1_ENDPOINT_HTTP=.*|L1_ENDPOINT_HTTP=${l1_endpoint_http}|" .env
sed -i "s|L1_ENDPOINT_WS=.*|L1_ENDPOINT_WS=${l1_endpoint_ws}|" .env
sed -i "s|L1_BEACON_HTTP=.*|L1_BEACON_HTTP=${l1_beacon_http}|" .env
sed -i "s|ENABLE_PROPOSER=.*|ENABLE_PROPOSER=${enable_proposer}|" .env
sed -i "s|L1_PROPOSER_PRIVATE_KEY=.*|L1_PROPOSER_PRIVATE_KEY=${l1_proposer_private_key}|" .env
sed -i "s|L2_SUGGESTED_FEE_RECIPIENT=.*|L2_SUGGESTED_FEE_RECIPIENT=${l2_suggested_fee_recipient}|" .env
sed -i "s|DISABLE_P2P_SYNC=.*|DISABLE_P2P_SYNC=${disable_p2p_sync}|" .env
sed -i 's|TX_GAS_LIMIT=.*|TX_GAS_LIMIT=|' .env

# 更新.env文件中的端口配置
sed -i "s|PORT_L2_EXECUTION_ENGINE_HTTP=.*|PORT_L2_EXECUTION_ENGINE_HTTP=${port_l2_execution_engine_http}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_WS=.*|PORT_L2_EXECUTION_ENGINE_WS=${port_l2_execution_engine_ws}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_METRICS=.*|PORT_L2_EXECUTION_ENGINE_METRICS=${port_l2_execution_engine_metrics}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_P2P=.*|PORT_L2_EXECUTION_ENGINE_P2P=${port_l2_execution_engine_p2p}|" .env
sed -i "s|PORT_PROVER_SERVER=.*|PORT_PROVER_SERVER=${port_prover_server}|" .env
sed -i "s|PORT_PROMETHEUS=.*|PORT_PROMETHEUS=${port_prometheus}|" .env
sed -i "s|PORT_GRAFANA=.*|PORT_GRAFANA=${port_grafana}|" .env
sed -i 's|PROVER_ENDPOINTS=.*|PROVER_ENDPOINTS=http://198.244.201.79:9876,https://prover-hekla.taiko.tools,https://prover2-hekla.taiko.tools,http://taiko-a7-prover.zkpool.io,http://146.59.55.26:9876,http://kenz-prover.hekla.kzvn.xyz:9876,http://hekla.stonemac65.xyz:9876,http://51.91.70.42:9876,http://taiko.web3crypt.net:9876,http://148.113.17.127:9876,http://hekla.prover.taiko.coinblitz.pro:9876,http://taiko-testnet.m51nodes.xyz:9876,http://148.113.16.26:9876,http://51.161.118.103:9876,http://162.19.98.173:9876,http://49.13.215.95:9876,http://49.13.143.184:9876,http://49.13.210.192:9876,http://159.69.242.22:9876,http://49.13.69.238:9876,http://taiko.guru:9876,http://taiko.donkamote.xyz:9876|' .env
sed -i "s|BLOCK_PROPOSAL_FEE=.*|BLOCK_PROPOSAL_FEE=99999|" .env

# 定义NEW_BOOT_NODES变量并初始化为空字符串
    NEW_BOOT_NODES="enode://0b310c7dcfcf45ef32dde60fec274af88d52c7f0fb6a7e038b14f5f7bb7d72f3ab96a59328270532a871db988a0bcf57aa9258fa8a80e8e553a7bb5abd77c40d@167.235.249.45:30303,enode://500a10f3a8cfe00689eb9d41331605bf5e746625ac356c24235ff66145c2de454d869563a71efb3d2fb4bc1c1053b84d0ab6deb0a4155e7227188e1a8457b152@85.10.202.253:30303"

# 读取当前的BOOT_NODES参数
    CURRENT_BOOT_NODES=$(grep -oP '^BOOT_NODES=\K.*' .env)

# 判断是否含有指定的enode
  if [[ "$CURRENT_BOOT_NODES" =~ "$NEW_BOOT_NODES" ]]; then
    echo "BOOT_NODES参数中已包含指定的enode"
  else
    # 在当前的BOOT_NODES参数后叠加指定的enode
    NEW_BOOT_NODES="${CURRENT_BOOT_NODES},${NEW_BOOT_NODES}"
    sed -i "s|^BOOT_NODES=.*|BOOT_NODES=${NEW_BOOT_NODES}|" .env
    echo "已成功添加指定的enode到BOOT_NODES参数中"
  fi
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

# 节点安装功能
function install_node2() {

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

# 从/root/record.txt文件中读取参数值
record_file="/root/record.txt"
l1_endpoint_http=$(grep "L1_ENDPOINT_HTTP=" "$record_file" | cut -d '=' -f 2)
l1_endpoint_ws=$(grep "L1_ENDPOINT_WS=" "$record_file" | cut -d '=' -f 2)
l1_proposer_private_key=$(grep "L1_PROPOSER_PRIVATE_KEY=" "$record_file" | cut -d '=' -f 2)
l2_suggested_fee_recipient=$(grep "L2_SUGGESTED_FEE_RECIPIENT=" "$record_file" | cut -d '=' -f 2)
l1_beacon_http="http://95.217.74.216:5052"
enable_proposer="true"
disable_p2p_sync="false"

# 设置默认端口值
port_l2_execution_engine_http=8547
port_l2_execution_engine_ws=8548
port_l2_execution_engine_metrics=6061
port_l2_execution_engine_p2p=30306
port_prover_server=9876
port_prometheus=9092
port_grafana=3001

# 将用户输入的值写入.env文件
sed -i "s|L1_ENDPOINT_HTTP=.*|L1_ENDPOINT_HTTP=${l1_endpoint_http}|" .env
sed -i "s|L1_ENDPOINT_WS=.*|L1_ENDPOINT_WS=${l1_endpoint_ws}|" .env
sed -i "s|L1_BEACON_HTTP=.*|L1_BEACON_HTTP=${l1_beacon_http}|" .env
sed -i "s|ENABLE_PROPOSER=.*|ENABLE_PROPOSER=${enable_proposer}|" .env
sed -i "s|L1_PROPOSER_PRIVATE_KEY=.*|L1_PROPOSER_PRIVATE_KEY=${l1_proposer_private_key}|" .env
sed -i "s|L2_SUGGESTED_FEE_RECIPIENT=.*|L2_SUGGESTED_FEE_RECIPIENT=${l2_suggested_fee_recipient}|" .env
sed -i "s|DISABLE_P2P_SYNC=.*|DISABLE_P2P_SYNC=${disable_p2p_sync}|" .env
sed -i 's|TX_GAS_LIMIT=.*|TX_GAS_LIMIT=|' .env

# 更新.env文件中的端口配置
sed -i "s|PORT_L2_EXECUTION_ENGINE_HTTP=.*|PORT_L2_EXECUTION_ENGINE_HTTP=${port_l2_execution_engine_http}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_WS=.*|PORT_L2_EXECUTION_ENGINE_WS=${port_l2_execution_engine_ws}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_METRICS=.*|PORT_L2_EXECUTION_ENGINE_METRICS=${port_l2_execution_engine_metrics}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_P2P=.*|PORT_L2_EXECUTION_ENGINE_P2P=${port_l2_execution_engine_p2p}|" .env
sed -i "s|PORT_PROVER_SERVER=.*|PORT_PROVER_SERVER=${port_prover_server}|" .env
sed -i "s|PORT_PROMETHEUS=.*|PORT_PROMETHEUS=${port_prometheus}|" .env
sed -i "s|PORT_GRAFANA=.*|PORT_GRAFANA=${port_grafana}|" .env
sed -i 's|PROVER_ENDPOINTS=.*|PROVER_ENDPOINTS=http://198.244.201.79:9876,https://prover-hekla.taiko.tools,https://prover2-hekla.taiko.tools,http://taiko-a7-prover.zkpool.io,http://146.59.55.26:9876,http://kenz-prover.hekla.kzvn.xyz:9876,http://hekla.stonemac65.xyz:9876,http://51.91.70.42:9876,http://taiko.web3crypt.net:9876,http://148.113.17.127:9876,http://hekla.prover.taiko.coinblitz.pro:9876,http://taiko-testnet.m51nodes.xyz:9876,http://148.113.16.26:9876,http://51.161.118.103:9876,http://162.19.98.173:9876,http://49.13.215.95:9876,http://49.13.143.184:9876,http://49.13.210.192:9876,http://159.69.242.22:9876,http://49.13.69.238:9876,http://taiko.guru:9876,http://taiko.donkamote.xyz:9876|' .env
sed -i "s|BLOCK_PROPOSAL_FEE=.*|BLOCK_PROPOSAL_FEE=99999|" .env

# 定义NEW_BOOT_NODES变量并初始化为空字符串
    NEW_BOOT_NODES="enode://0b310c7dcfcf45ef32dde60fec274af88d52c7f0fb6a7e038b14f5f7bb7d72f3ab96a59328270532a871db988a0bcf57aa9258fa8a80e8e553a7bb5abd77c40d@167.235.249.45:30303,enode://500a10f3a8cfe00689eb9d41331605bf5e746625ac356c24235ff66145c2de454d869563a71efb3d2fb4bc1c1053b84d0ab6deb0a4155e7227188e1a8457b152@85.10.202.253:30303"

# 读取当前的BOOT_NODES参数
    CURRENT_BOOT_NODES=$(grep -oP '^BOOT_NODES=\K.*' .env)

# 判断是否含有指定的enode
  if [[ "$CURRENT_BOOT_NODES" =~ "$NEW_BOOT_NODES" ]]; then
    echo "BOOT_NODES参数中已包含指定的enode"
  else
    # 在当前的BOOT_NODES参数后叠加指定的enode
    NEW_BOOT_NODES="${CURRENT_BOOT_NODES},${NEW_BOOT_NODES}"
    sed -i "s|^BOOT_NODES=.*|BOOT_NODES=${NEW_BOOT_NODES}|" .env
    echo "已成功添加指定的enode到BOOT_NODES参数中"
  fi
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
function change_rpc() {
  cd $HOME
  cd simple-taiko-node

  rpc_list=(
    "http://198.244.201.79:9876"
    "https://prover-hekla.taiko.tools"
    "https://prover2-hekla.taiko.tools"
    "http://taiko-a7-prover.zkpool.io"
    "http://146.59.55.26:9876"
    "http://kenz-prover.hekla.kzvn.xyz:9876"
    "http://hekla.stonemac65.xyz:9876"
    "http://51.91.70.42:9876"
    "http://taiko.web3crypt.net:9876"
    "http://148.113.17.127:9876"
    "http://hekla.prover.taiko.coinblitz.pro:9876"
    "http://taiko-testnet.m51nodes.xyz:9876"
    "http://148.113.16.26:9876"
    "http://51.161.118.103:9876"
    "http://162.19.98.173:9876"
    "http://49.13.215.95:9876"
    "http://49.13.143.184:9876"
    "http://49.13.210.192:9876"
    "http://159.69.242.22:9876"
    "http://49.13.69.238:9876"
    "http://taiko.guru:9876"
    "http://taiko.donkamote.xyz:9876"
  )

  rpc_string=""

  existing_rpc=$(grep -oE 'PROVER_ENDPOINTS=([^"]+)' .env | cut -d '=' -f 2)
  rpc_already_exist=0

  echo "当前的 PROVER_ENDPOINTS: $existing_rpc"
  read -p "是否确认更新？(输入 y 进行更新，输入其他结束): " confirm

  if [ "$confirm" != "y" ]; then
    echo "取消更新"
    return
  fi

  for rpc in "${rpc_list[@]}"
  do
    if [[ "$existing_rpc" != *"$rpc"* ]]; then
      rpc_string="$rpc_string$rpc,"
    fi
  done

  if [ -z "$rpc_string" ]; then
    echo "已经更新过prover rpc"
  else
    rpc_string="${rpc_string%,}"
    sed -i "s|PROVER_ENDPOINTS=.*|PROVER_ENDPOINTS=${existing_rpc},${rpc_string}|" .env
    echo "成功更新prover rpc"
    docker compose --profile l2_execution_engine down
    docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
    docker compose --profile l2_execution_engine up -d
    docker compose up taiko_client_proposer -d
  fi
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


while true; do
    echo "当前的Beacon Holskey RPC链接为: $(grep L1_BEACON_HTTP .env | cut -d '=' -f2)"
    echo "请选择操作:"
    echo "1. 设置Beacon Holskey RPC链接为 http://195.201.170.121:5052"
    echo "2. 设置Beacon Holskey RPC链接为 http://188.40.51.249:5052"
    echo "3. 设置Beacon Holskey RPC链接为 http://95.217.74.216:5052"
    echo "4. 设置Beacon Holskey RPC链接为 http://138.201.221.84:5052"
    echo "5. 设置Beacon Holskey RPC链接为 http://195.201.9.8:5052 (推荐)"
    echo "6. 设置Beacon Holskey RPC链接为 http://95.217.58.227:5052 (推荐)"
    echo "7. 设置Beacon Holskey RPC链接为 http://95.216.229.50:5052 (推荐)"
    echo "8. 设置Beacon Holskey RPC链接为 http://95.216.28.36:5052 (推荐)"
    echo "9. 设置自定义Beacon Holskey RPC链接"
    read -p "请输入选项: " choice

    case $choice in
        1)
            l1_beacon_http='http://195.201.170.121:5052'
            break
            ;;
        2)
            l1_beacon_http='http://188.40.51.249:5052'
            break
            ;;
        3)
            l1_beacon_http='http://95.217.74.216:5052'
            break
            ;;
        4)
            l1_beacon_http='http://138.201.221.84:5052'
            break
            ;;
        5)
            l1_beacon_http='http://195.201.9.8:5052'
            break
            ;;
        6)
            l1_beacon_http='http://95.217.58.227:5052'
            break
            ;;
        7)
            l1_beacon_http='http://95.216.229.50:5052'
            break
            ;;
        8)
            l1_beacon_http='http://95.216.28.36:5052'
            break
            ;;
        9)
            read -p "请输入自定义Beacon Holskey RPC链接: " l1_beacon_http
            break
            ;;
        *)
            echo "无效的选项，请重新输入"
            ;;
    esac
done

# 更新 .env 文件中的 L1_BEACON_HTTP 值
sed -i "s|L1_BEACON_HTTP=.*|L1_BEACON_HTTP=${l1_beacon_http}|" .env
echo "Beacon Holskey RPC链接已更新为: $l1_beacon_http"

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

  # 定义NEW_BOOT_NODES变量并初始化为空字符串
  NEW_BOOT_NODES="enode://0b310c7dcfcf45ef32dde60fec274af88d52c7f0fb6a7e038b14f5f7bb7d72f3ab96a59328270532a871db988a0bcf57aa9258fa8a80e8e553a7bb5abd77c40d@167.235.249.45:30303,enode://500a10f3a8cfe00689eb9d41331605bf5e746625ac356c24235ff66145c2de454d869563a71efb3d2fb4bc1c1053b84d0ab6deb0a4155e7227188e1a8457b152@85.10.202.253:30303"

  # 读取当前的BOOT_NODES参数
  CURRENT_BOOT_NODES=$(grep -oP '^BOOT_NODES=\K.*' .env)

  # 判断是否含有指定的enode
  if [[ "$CURRENT_BOOT_NODES" =~ "$NEW_BOOT_NODES" ]]; then
    echo "BOOT_NODES参数中已包含指定的enode"
  else
    # 在当前的BOOT_NODES参数后叠加指定的enode
    NEW_BOOT_NODES="${CURRENT_BOOT_NODES},${NEW_BOOT_NODES}"
    sed -i "s|^BOOT_NODES=.*|BOOT_NODES=${NEW_BOOT_NODES}|" .env
    echo "已成功添加指定的enode到BOOT_NODES参数中"
    
    docker compose --profile l2_execution_engine down
    docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
    docker compose --profile l2_execution_engine up -d
    docker compose up taiko_client_proposer -d

    echo "⠿ Network simple-taiko-node_default  Error报错可忽略"
    
  fi
}

function set_fee(){
    echo "请选择需要支付的BLOCK_PROPOSAL_FEE："
    echo "1. 1"
    echo "2. 30(默认)"
    echo "3. 80"
    echo "4. 300"
    echo "5. 500"
    echo "6. 1000"
    echo "7. 5000"
    echo "8. 9999"
    echo "9. 99999"
    read -p "请输入选项编号：" option

    case $option in
        1)
            BLOCK_PROPOSAL_FEE=1
            ;;
        2)
            BLOCK_PROPOSAL_FEE=30
            ;;
        3)
            BLOCK_PROPOSAL_FEE=80
            ;;
        4)
            BLOCK_PROPOSAL_FEE=300
            ;;
        5)
            BLOCK_PROPOSAL_FEE=500
            ;;
        6)
            BLOCK_PROPOSAL_FEE=1000
            ;;
        7)
            BLOCK_PROPOSAL_FEE=5000
            ;;
        8)
            BLOCK_PROPOSAL_FEE=9999
            ;;
        9)
            BLOCK_PROPOSAL_FEE=99999
            ;;
        *)
            echo "无效的选项"
            return
            ;;
    esac
    
    cd $HOME/simple-taiko-node
    sed -i "s|BLOCK_PROPOSAL_FEE=.*|BLOCK_PROPOSAL_FEE=$BLOCK_PROPOSAL_FEE|" .env
    docker compose --profile l2_execution_engine down
    docker stop simple-taiko-node-taiko_client_proposer-1 && docker rm simple-taiko-node-taiko_client_proposer-1
    docker compose --profile l2_execution_engine up -d
    docker compose --profile proposer up -d
}


# 主菜单
function main_menu() {
    
    clear
    echo "============================自用脚本============================="
    echo "需要测试网节点部署托管 技术指导 部署领水质押脚本 请联系Telegram :https://t.me/linzeusasa"
    echo "===================Taiko最新测试网节点一键部署===================="
    echo "从未安装过Taiko的vps请执行安装节点--查看节点日志"
    echo "安装过旧版本或者需要重装节点的vps请执行卸载旧版本--安装节点--查看节点日志"
    echo "请定期检查BlockPI rpc流量，不足时请执行更换BlockPI rpc"
    echo "发现高度同步长时间追不上 请执行切换BlockPI rpc尝试 优先第4条rpc"
    echo "请选择要执行的操作:"
    echo "1. 卸载节点"
    echo "2. 安装节点"
    echo "3. 更新参数信息"
    echo "4. 查询信息"
    echo "5. 重启Taiko节点"
    echo "6. 免输安装节点(请先执行查询信息中的记录参数功能)"
    read -p "请输入选项（1-5）: " OPTION

    case $OPTION in
        1) delete ;;
        2) install_node1 ;;
        3) change_parameters_info ;;
        4) query_info ;;
        5) restart ;;
        6) install_node2 ;;
        *) echo "无效选项。" ;;
    esac
}


# 显示主菜单
main_menu
