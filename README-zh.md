---

# OpenVPN 安装与自动化用户管理 (增强版)

本项目基于 [angristan/openvpn-install](https://github.com/angristan/openvpn-install) 脚本，结合企业级自动化管理需求，
提供了更全面的**OpenVPN 一键安装、配置与批量用户管理解决方案**，支持通过命令行或 Web API 实现零交互的全流程自动运维。

---

## ✨ 主要增强功能

* **openvpn-ctl** 脚本：全自动参数化管理用户（新增、吊销、重置、导出等），支持自定义 .ovpn 输出目录，兼容任何 bash/CI 自动化环境。
* **Python Web 服务（API）**：基于 FastAPI，开放全部管理接口（新增/吊销/重置/导出/批量操作），适配 HTTP 自动化和第三方平台对接。
* **完美兼容原始脚本、支持环境变量、支持多系统、支持批量运维和开机自启。**
* **增强的接口文档与部署说明**，便于企业集成和运维团队快速落地。

---

## 📦 目录结构

```
openvpn-manager/
├── openvpn-install.sh          # 原始一键安装脚本
├── openvpn-ctl                # 用户自动化管理脚本（增强）
├── app.py                     # Python Web API服务（增强）
├── requirements.txt           # Python依赖
├── README-zh.md               # 中文说明文档（本文件）
└── (systemd配置/运维脚本等)
```

---

## 🚀 一键部署与安装

### 1. 获取代码

```
git clone https://github.com/astralwaveio/openvpn-install.git
cd openvpn-install
chmod +x openvpn-install.sh openvpn-ctl
```

### 2. 安装 Python 依赖

```
pip3 install -r requirements.txt
```

### 3. (可选) 配置 .ovpn 文件输出目录

```
export OVPN_OUTPUT_DIR="/data/openvpn-clients"
mkdir -p /data/openvpn-clients
```

### 4. 初始化 OpenVPN（首次安装）

> 建议首次用 `openvpn-install.sh` 交互式完成一次服务端初始化
> 后续仅用 `openvpn-ctl` 和 Web API 进行日常用户管理。

```
sudo bash openvpn-install.sh
```

---

## 🛠 openvpn-ctl 脚本用法（命令行管理）

openvpn-ctl 是基于官方脚本的**自动化用户管理增强工具**，支持：

* 新增用户（可选密码）
* 吊销用户
* 重置（吊销再建）用户
* 查看用户配置
* 导出配置到指定路径
* 完全参数化、可集成API或批量运维

### 使用说明

```
Usage:
  ./openvpn-ctl add <用户名> [--pass <密码>]           # 新增用户（可指定私钥密码）
  ./openvpn-ctl revoke <用户名>                        # 吊销用户
  ./openvpn-ctl list                                  # 列出所有用户
  ./openvpn-ctl regen <用户名> [--pass <密码>]         # 重置用户
  ./openvpn-ctl show <用户名>                          # 输出.ovpn配置
  ./openvpn-ctl export <用户名> <导出路径>             # 导出.ovpn到指定文件

参数说明:
  --pass <密码>       设置用户私钥密码（可选，add/regen 支持）

环境变量:
  OPENVPN_SCRIPT      指定 openvpn-install.sh 路径（默认同目录）
  OVPN_OUTPUT_DIR     指定 .ovpn 文件输出/查找目录（推荐统一管理）

示例：
  ./openvpn-ctl add alice
  ./openvpn-ctl add bob --pass MyPass123
  ./openvpn-ctl revoke alice
  ./openvpn-ctl regen bob --pass NewPass
  ./openvpn-ctl show bob
  ./openvpn-ctl export bob /tmp/bob.ovpn
```

### 授权

执行前请授权 shell 脚本

```shell
chmod +x openvpn-install.sh
chmod +x openvpn-ctl.sh
```
---

## 🌐 Web API 接口文档（增强版）

通过 `app.py` 启动 HTTP 服务，**所有功能均可通过接口调用，适配企业自动化/平台对接。**

### 启动服务

```
uvicorn app:app --host 0.0.0.0 --port 8000
```

访问 `http://服务器:8000/docs` 可在线浏览与调试全部接口（Swagger 文档）。

### 常用接口

#### 1. 新增用户

* **POST** `/add_user`
* **参数：**

  * username (str)：用户名，必填
  * password (str)：私钥密码，选填
* **响应：**

  * username
  * ovpn（配置文件内容）

#### 2. 吊销用户

* **POST** `/revoke_user`
* **参数：**

  * username (str)：用户名，必填
* **响应：**

  * username
  * status: "revoked"

#### 3. 重置用户

* **POST** `/regen_user`
* **参数：**

  * username (str)：用户名，必填
  * password (str)：新私钥密码，选填
* **响应：**

  * username
  * ovpn（新配置内容）
  * status: "regenerated"

#### 4. 列出所有用户

* **POST** `/list_users`
* **响应：**

  * users: 用户列表数组

#### 5. 查询.ovpn配置

* **POST** `/show_ovpn`
* **参数：**

  * username (str)：用户名
* **响应：**

  * 直接返回 .ovpn 文件内容（text/plain）

#### 6. 导出.ovpn到指定路径

* **POST** `/export_ovpn`
* **参数：**

  * username (str)：用户名
  * output\_path (str)：导出目标路径
* **响应：**

  * username
  * exported\_to: 文件路径

### 接口统一异常返回

```
{
  "detail": "错误信息"
}
```

### curl 示例

```
# 新增用户
curl -X POST http://localhost:8000/add_user \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"secret123"}'

# 吊销
curl -X POST http://localhost:8000/revoke_user \
  -H "Content-Type: application/json" \
  -d '{"username":"alice"}'

# 查询
curl -X POST http://localhost:8000/show_ovpn \
  -H "Content-Type: application/json" \
  -d '{"username":"alice"}'
```

---

## 🧩 系统服务与开机自启

创建 `/etc/systemd/system/openvpn-api.service`：

```
[Unit]
Description=OpenVPN Client Management API Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/openvpn-manager/app.py
WorkingDirectory=/opt/openvpn-manager
Restart=always
User=root
Environment="OVPN_OUTPUT_DIR=/data/openvpn-clients"

[Install]
WantedBy=multi-user.target
```

```
systemctl daemon-reload
systemctl enable openvpn-api
systemctl start openvpn-api
```

---

## 🔒 安全与生产环境建议

* 强烈建议 API 服务仅监听内网IP，必要时配合防火墙与API认证
* OVPN\_OUTPUT\_DIR 目录建议权限专属，仅限 root 管理
* 所有用户相关操作均有日志输出，建议定期审计
* 建议将 openvpn-ctl 集成至堡垒机、自动化运维平台等

---

## 🛠 常见问题与最佳实践

1. **问：openvpn-install.sh 必须和 openvpn-ctl 在同一目录吗？**
   答：是，默认如此（也可通过环境变量 OPENVPN\_SCRIPT 指定）。

2. **问：批量用户怎么管理？**
   答：无论是 openvpn-ctl 还是 API，都可脚本循环批量调用。

3. **问：可否自定义.ovpn存储目录？**
   答：可，建议设置 `export OVPN_OUTPUT_DIR=/data/openvpn-clients`。

4. **问：支持哪些操作系统？**
   答：Debian/Ubuntu、CentOS/RHEL、支持 Bash 与 Python3 环境。

---

## 📝 参考原始用法

**原始安装/管理命令行（见英文 README）**

* 一键交互式安装服务端：

  ```
  sudo bash openvpn-install.sh
  ```
* 后续建议只用 openvpn-ctl 进行用户管理
* 所有用户文件默认输出至指定目录或 /root/

---

## ❤️ 社区与反馈

本项目由 [angristan/openvpn-install](https://github.com/angristan/openvpn-install) 社区脚本二次增强，
如需更多支持、业务集成、定制化开发，欢迎 issue 或邮件联系维护者。

---

（本文件为增强版中文文档，更多说明参见原始英文README和代码注释）


