#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Taiko-v2.sh"


function delete() {
    echo "正在卸载，请稍等······"
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

    # 返回主菜单
    main_menu
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

# 从/root/record.txt文件中读取值
record_file="/root/record.txt"
l1_endpoint_http=$(sed -n '1p' $record_file)
l1_endpoint_ws=$(sed -n '2p' $record_file)
l1_beacon_http="http://unstable.holesky.beacon-api.nimbus.team"
enable_proposer="true"
disable_p2p_sync="false"
l1_proposer_private_key=$(sed -n '3p' $record_file)
l2_suggested_fee_recipient=$(sed -n '4p' $record_file)

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

# 更新.env文件中的端口配置
sed -i "s|PORT_L2_EXECUTION_ENGINE_HTTP=.*|PORT_L2_EXECUTION_ENGINE_HTTP=${port_l2_execution_engine_http}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_WS=.*|PORT_L2_EXECUTION_ENGINE_WS=${port_l2_execution_engine_ws}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_METRICS=.*|PORT_L2_EXECUTION_ENGINE_METRICS=${port_l2_execution_engine_metrics}|" .env
sed -i "s|PORT_L2_EXECUTION_ENGINE_P2P=.*|PORT_L2_EXECUTION_ENGINE_P2P=${port_l2_execution_engine_p2p}|" .env
sed -i "s|PORT_PROVER_SERVER=.*|PORT_PROVER_SERVER=${port_prover_server}|" .env
sed -i "s|PORT_PROMETHEUS=.*|PORT_PROMETHEUS=${port_prometheus}|" .env
sed -i "s|PORT_GRAFANA=.*|PORT_GRAFANA=${port_grafana}|" .env
sed -i 's|PROVER_ENDPOINTS=.*|PROVER_ENDPOINTS=http://kenz-prover.hekla.kzvn.xyz:9876,http://hekla.stonemac65.xyz:9876,http://taiko.web3crypt.net:9876/,http://198.244.201.79:9876,http://taiko-a7-prover.zkpool.io,http://148.113.17.127:9876,http://146.59.55.26:9876,http://hekla.prover.taiko.coinblitz.pro:9876,https://prover-hekla.taiko.tools,https://prover2-hekla.taiko.tools,http://taiko-testnet.m51nodes.xyz:9876,http://148.113.16.26:9876|' .env
sed -i "s|BLOCK_PROPOSAL_FEE=.*|BLOCK_PROPOSAL_FEE=80|" .env

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



# 主菜单
function main_menu() {
    clear
    echo "=====================专用脚本 盗者必究==========================="
    echo "需要测试网节点部署托管 技术指导 定制脚本 请联系Telegram :https://t.me/linzeusasa"
    echo "需要测试网节点部署托管 技术指导 定制脚本 请联系Wechat :llkkxx001"
    echo "请选择要执行的操作:"
    echo "1. 完全卸载节点"
    echo "2. 记录配置信息"
    echo "3. 安装节点"
    echo "4. 查询节点日志"
    echo "5. 重启Taiko节点"
    read -p "请输入选项（1-4）: " OPTION

    case $OPTION in
    1) delete ;;
    2) record ;;
    3) install_node ;;
    4) check_service_status ;;
    5) restart ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
