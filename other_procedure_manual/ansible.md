ansible導入手順
# apt install -y ansible-core

# ansible --version
ansible [core 2.19.0b6]
  config file = None
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible
  python version = 3.13.5 (main, Jun 25 2025, 18:55:22) [GCC 14.2.0] (/usr/bin/python3)
  jinja version = 3.1.6
  pyyaml version = 6.0.2 (with libyaml v0.2.5)

# mkdir /etc/ansible

# nano /etc/ansible/ansible.cfg
以下を追記
---------------
[defaults]
inventory = /etc/ansible/hosts
timeout = 0
remote_user = root
host_key_checking = False
command_warnings = False
deprecation_warnings = False
log_path = /var/log/ansible.log
interpreter_python = /opt/ansible-vmw/bin/python
collections_paths = /root/.ansible/collections:/usr/share/ansible/collections
stdout_callback = yaml

[ssh_connection]
ssh_args = -o ServerAliveInterval=60 -o ServerAliveCountMax=999999
---------------


▼pipのインストール
apt install -y python3-pip
pip3 --version

▼authorized_key.ymlの実行に必要

- モジュールインストール

apt-get install -y sshpass

- RSA鍵作成

(※既に鍵を作成済みの場合は実施不要)

ssh-keygen -t rsa -b 4096

- 鍵のコピー

(※既に鍵を作成済みの場合は実施不要)

cp -p /root/.ssh/id_rsa.pub /etc/ansible/roles/authorized_key/files/ansible_key

▼collect_nic.yml、mount.yml の実行に必要

- 仮想環境作成

mkdir -p /opt/ansible-vmw
chown $(whoami):$(whoami) /opt/ansible-vmw
apt install -y python3.11-venv
python3 -m venv /opt/ansible-vmw
ls -l /opt/ansible-vmw/bin/python

- モジュールインストール

export https_proxy=http://[ProxyのIP]:8080

env | grep -i proxy

pip3 install paramiko --break-system-packages

▼VMcreate の実行に必要
/opt/ansible-vmw/bin/pip install proxmoxer
/opt/ansible-vmw/bin/pip install requests

▼shutdown_vm.yml の実行に必要
ansible-galaxy collection install community.vmware --upgrade
/opt/ansible-vmw/bin/pip install pyvmomi

▼delete_vm.yml の実行に必要

pip3 install --upgrade pyvmomi --break-system-packages

pip3 list | grep pyvmomi

→ バージョンが9.0.0.0以上であること

▼migration.yml の実行に必要

- virt-v2vインストール

apt install -y virt-v2v libguestfs-tools libnbd-bin nbdkit supermin

- vddkのインストール

mkdir -p /opt/vddk
cd /opt/vddk

・dev-Ansible(172.16.40.179)に配置済みのファイルscpで対象サーバーに配置する。
scp -p 172.16.40.179:/root/VMware-vix-disklib-8.0.0-20521017.x86_64.tar.gz ./
tar -xzvf VMware-vix-disklib-8.0.0-20521017.x86_64.tar.gz

・nbdkitソース入手&ビルド
apt install -y gcc make libtool automake pkg-config libglib2.0-dev libxml2-dev libguestfs-dev

cd /root
wget https://download.libguestfs.org/nbdkit/1.32-stable/nbdkit-1.32.5.tar.gz
tar xvf nbdkit-1.32.5.tar.gz
cd nbdkit-1.32.5

./configure --with-vddk=/opt/vddk/vmware-vix-disklib-distrib
make

install -D -m 0644 plugins/vddk/.libs/nbdkit-vddk-plugin.so /usr/lib/x86_64-linux-gnu/nbdkit/plugins/nbdkit-vddk-plugin.so

・nbdkitのインストール確認

which nbdkit

出力例:
——
/usr/local/sbin/nbdkit
——-

・nbdkit に vddk プラグインが有効か確認
nbdkit vddk --dump-plugin

出力例（抜粋）:
—-
name=vddk
vddk_default_libdir=/usr/local/lib/vmware-vix-disklib
—-

▼centos5_migration.ymlの実行に必要

apt install sshpass

▼lb_operation.ymlの実行に必要

(上記のsshpassも必要)

ansible-galaxy collection install netscaler.adc




root@pve01:/etc/ansible# ls
ansible.cfg    generate_ansible_vars.py  lb_operation.yml        migration.yml  vminfo_results
delete_vm.yml  inventories               legacyos_migration.yml  roles

root@pve01:/etc/ansible# cat ansible.cfg 
[defaults]
inventory = /etc/ansible/hosts
timeout = 0
remote_user = root
host_key_checking = False
command_warnings = False
deprecation_warnings = False
log_path = /var/log/ansible.log
interpreter_python = /opt/ansible-vmw/bin/python
collections_paths = /root/.ansible/collections:/usr/share/ansible/collections
stdout_callback = yaml

[ssh_connection]
ssh_args = -o ServerAliveInterval=60 -o ServerAliveCountMax=999999

root@pve01:/etc/ansible# cat generate_ansible_vars.py 
#!/usr/bin/env python3
import sys
import json
import ssl
import os
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
import paramiko

# vCenter接続情報
vcenter_host = os.environ.get('VCENTER_HOST')
vcenter_user = os.environ.get('VCENTER_USER')
vcenter_password = os.environ.get('VCENTER_PASSWORD')

# ゲストOS SSH接続情報
guest_user = os.environ.get('GUEST_USER')
guest_password = os.environ.get('GUEST_PASSWORD')


def get_vm_network_details(si, target_vms):
    """
    vCenterからVMのMACアドレスと、それに対応するVLAN IDを取得する
    """
    content = si.RetrieveContent()
    vm_view = content.viewManager.CreateContainerView(
        content.rootFolder,
        [vim.VirtualMachine],
        True
    )

    vms_info = {}

    for vm in vm_view.view:
        if vm.name not in target_vms:
            continue

        nic_details = {}

        for device in vm.config.hardware.device:
            if not isinstance(device, vim.vm.device.VirtualEthernetCard):
                continue
            if not device.macAddress:
                continue

            mac_addr = device.macAddress.lower()
            vlan_id = "Not Found"

            backing = device.backing

            # パターンA: 分散スイッチ (vDS)
            if hasattr(backing, 'port') and backing.port:
                try:
                    pg_key = backing.port.portgroupKey
                    pg_container = content.viewManager.CreateContainerView(
                        content.rootFolder,
                        [vim.dvs.DistributedVirtualPortgroup],
                        True
                    )
                    for pg in pg_container.view:
                        if pg.key == pg_key:
                            cfg = pg.config.defaultPortConfig
                            if hasattr(cfg, 'vlan') and hasattr(cfg.vlan, 'vlanId'):
                                vlan_val = cfg.vlan.vlanId
                                vlan_id = str(vlan_val) if isinstance(vlan_val, int) else "Trunk/Range"
                            break
                    pg_container.Destroy()
                except Exception:
                    vlan_id = "Error(vDS)"

            # パターンB: 標準スイッチ (vSS)
            elif hasattr(backing, 'deviceName'):
                try:
                    pg_name = backing.deviceName
                    if vm.runtime.host:
                        host = vm.runtime.host
                        net_system = host.configManager.networkSystem
                        if net_system:
                            for pg in net_system.networkInfo.portgroup:
                                if pg.spec.name == pg_name:
                                    vlan_id = str(pg.spec.vlanId)
                                    break
                except Exception:
                    vlan_id = "Error(vSS)"

            nic_details[mac_addr] = {'vlan_id': vlan_id}

        if nic_details:
            vms_info[vm.name] = {
                'nics': nic_details,          # MACアドレスをキーとした詳細情報
                'guest_ip': vm.guest.ipAddress  # 参考値（Solarisでは取れないこ とがある）
            }

    vm_view.Destroy()
    return vms_info


def get_guest_nic_names(ssh_target, mac_addresses):
    """
    ゲストOSにSSHで接続し、MACアドレスに対応するNIC名を取得する
    Linux想定: `ip -o link`
    Solaris想定: `ifconfig -a`
    """
    if not ssh_target:
        print("SSH接続先が不明なため、NIC名の取得をスキップします。", file=sys.stderr)
        return {}

    mac_set = set([m.lower() for m in mac_addresses])
    nic_map = {}

    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(
            ssh_target,
            username=guest_user,
            password=guest_password,
            timeout=10,
            # Paramiko 2.6以降で古いアルゴリズムを許可するための設定
            disabled_algorithms={'pubkeys': [], 'kex': []},
            look_for_keys=False,
            allow_agent=False
        )

        # まずLinux向け（ip）を試す
        cmd_linux = "ip -o link"
        stdin, stdout, stderr = client.exec_command(cmd_linux)
        out_text = stdout.read().decode(errors='ignore')
        err_text = stderr.read().decode(errors='ignore')

        if out_text.strip():
            # Linux: "2: ens160: <...> link/ether 00:50:..."
            for line in out_text.splitlines():
                parts = line.strip().split()
                if len(parts) < 2:
                    continue
                nic_name = parts[1].strip(':')
                if 'link/ether' in parts:
                    try:
                        mac_index = parts.index('link/ether') + 1
                        mac = parts[mac_index].lower()
                        if mac in mac_set:
                            nic_map[mac] = nic_name
                    except (ValueError, IndexError):
                        continue
        else:
            # Solaris向け（ifconfig）
            cmd_sol = "ifconfig -a"
            stdin, stdout, stderr = client.exec_command(cmd_sol)
            out_text = stdout.read().decode(errors='ignore')

            # Solaris: インタフェースブロックから `ether 0:50:56:...` を拾う
            current_if = None
            for line in out_text.splitlines():
                line = line.rstrip()

                # "e1000g0: flags=..."
                if line and not line.startswith(' ') and line.endswith(':'):
                    current_if = line[:-1]
                    continue

                # "        ether 0:50:56:a0:7a:ce"
                if 'ether ' in line and current_if:
                    try:
                        mac = line.split('ether', 1)[1].strip().lower()
                        # SolarisのMACが "0:50:..." の形式ならゼロ埋めして正規化
                        mac_parts = mac.split(':')
                        mac_norm = ':'.join([p.zfill(2) for p in mac_parts])
                        if mac_norm in mac_set:
                            nic_map[mac_norm] = current_if
                    except Exception:
                        continue

        client.close()
        return nic_map

    except Exception as e:
        print(f"SSH({ssh_target}) でNIC名取得に失敗しました: {e}", file=sys.stderr)
        return {}


def main():
    # コマンドライン引数を処理して対象VMを特定する
    # 第1引数: vCenter 上の VM 名
    # 第2引数: ゲストOSへの SSH 接続先（省略時は VM 名）
    if len(sys.argv) < 2:
        print("Error: No target VM specified on the command line.", file=sys.stderr)
        sys.exit(1)

    vm_name = sys.argv[1]
    target = sys.argv[2] if len(sys.argv) > 2 else vm_name

    # 複数VM前提の関数と整合させるため list にする
    target_vms = [vm_name]

    # SSL証明書の検証を無効化
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    si = None
    try:
        si = SmartConnect(
            host=vcenter_host,
            user=vcenter_user,
            pwd=vcenter_password,
            port=443,
            sslContext=context
        )

        if not si:
            print("vCenterへの接続に失敗しました。", file=sys.stderr)
            sys.exit(1)

        # VLAN情報はvCenterから取得
        vms_info = get_vm_network_details(si, target_vms)
        if vm_name not in vms_info:
            print(f"vCenterからVM '{vm_name}' のNIC情報が取得できませんでした。", file=sys.stderr)
            sys.exit(1)

        info = vms_info[vm_name]
        nics_to_configure = []

        # vCenterから取得したMACアドレス一覧（SSHでNIC名対応付けに使う）
        vcenter_mac_keys = list(info['nics'].keys())

        # SSH接続は引数の target を優先（vCenter guest_ip は当てにしない）
        print(f"VM '{vm_name}' (SSH target: {target}) のNIC情報を取得中...", file=sys.stderr)
        nic_map_from_guest = get_guest_nic_names(target, vcenter_mac_keys)

        if not nic_map_from_guest:
            print(f"[DEBUG] vCenter MACs: {sorted(vcenter_mac_keys)}", file=sys.stderr)

        # SSHで取れたNIC名とvCenterのVLAN情報をマージ
        for mac, name in nic_map_from_guest.items():
            vlan_id = info['nics'].get(mac, {}).get('vlan_id', 'Unknown')
            nics_to_configure.append({
                'mac': mac,
                'name': name,
                'vlan_id': vlan_id
            })

        # --- 【改修箇所】情報が取得できたかチェック ---
        # nics_to_configure が空の場合は、エラー扱いとしてファイル作成せず終了する
        if not nics_to_configure:
            print(f"VM '{vm_name}' のNIC情報が取得できませんでした（情報が空です）。JSONファイルの作成をスキップします。", file=sys.stderr)
            sys.exit(1)
        # ----------------------------------------

        output_data = {'nics_to_configure': nics_to_configure}

        # 標準出力にJSONを出力（Ansible側で見たい場合用）
        print(json.dumps(output_data))

        # 一時ファイルにJSONを保存
        output_filename = f"/tmp/{vm_name}_nic_data.json"
        
        try:
            with open(output_filename, 'w') as f:
                json.dump(output_data, f)
            print(f"Successfully wrote NIC data to {output_filename}", file=sys.stderr)
        except Exception as e:
            print(f"ファイルの書き込みに失敗しました: {e}", file=sys.stderr)
            sys.exit(1)

    except Exception as e:
        print(f"スクリプトの実行中にエラーが発生しました: {e}", file=sys.stderr)
        sys.exit(1)

    finally:
        if si:
            Disconnect(si)


if __name__ == '__main__':
    main()
    
root@pve01:/etc/ansible# cat lb_operation.yml 
---
- name: NetScaler LB Server Disable/Enable
  hosts: migrationserver_all, legacyos_migrationserver_all
  gather_facts: false
  connection: local
  roles:
    - lb_operation


root@pve01:/etc/ansible# cat migration.yml 
---
- name: Target host migration to Proxmox
  hosts: vcenter65_migrationserver,vcenter70_migrationserver
  become: true
  gather_facts: no
  roles:
    - { role: collect_vminfo_before, tags: [ never,pre_migrate,cvb,ALL ] }
    - { role: authorized_key, tags: [ never,pre_migrate,authorized_key,ALL ] }
    - { role: collect_nic, tags: [ never,pre_migrate,collect_nic,ALL ] }
    - { role: fix_yum_repo, tags: [ never,pre_migrate,fix_yum_repo,ALL ] }
    - { role: vmcreate, tags: [ never,pre_migrate,vmcreate,ALL ] }
    - { role: shutdown_vm, tags: [ never,migrate,shutdown_vm,ALL ] }
    - { role: migration, tags: [ never,migrate,migration,ALL ] }
    - { role: mount, tags: [ never,migrate,mount,ALL ] }
    - { role: poweron_vm, tags: [ never,migrate,poweron_vm,ALL ] }
    - { role: collect_vminfo_after, tags: [ never,migrate,cva,ALL ] }
  pre_tasks:
    - name: "対象VMからPythonのパスを動的に取得"
      ansible.builtin.raw: "command -v python || command -v python3 || command -v python2"
      register: python_path_cmd
      delegate_to: "{{ inventory_hostname }}"
      changed_when: false
      ignore_errors: true
      ignore_unreachable: true
      check_mode: false 
      tags: [ always, ALL ]

    - name: "取得したPythonパスを変数(ansible_python_interpreter)としてセット"
      ansible.builtin.set_fact:
        ansible_python_interpreter: >-
          {{
            python_path_cmd.stdout_lines | last | trim
            if (
              python_path_cmd.unreachable is not defined and 
              python_path_cmd is not skipped and 
              python_path_cmd.rc | default(1) == 0 and 
              python_path_cmd.stdout | default('') != ''
            )
            else '/usr/bin/python3'
          }}
      tags: [ always, ALL ]


root@pve01:/etc/ansible# cat legacyos_migration.yml 
---
- name: Target legacyOS host migration to Proxmox
  hosts: vcenter65_legacyos_migrationserver,vcenter70_legacyos_migrationserver
  become: true
  gather_facts: no
  roles:
    - { role: collect_vminfo_before, tags: [ never,cvb_legacyos,ALL_legacyos ] }
    - { role: legacyos_migration, tags: [ never,migrate_legacyos,ALL_legacyos ] }
    - { role: poweron_vm, tags: [ never,poweron_legacyos,ALL_legacyos ] }
    - { role: collect_vminfo_after, tags: [ never,cva_legacyos,ALL_legacyos ] }
  pre_tasks:
    - name: "対象VMからOSバージョンを取得"
      ansible.builtin.raw: "cat /etc/redhat-release"
      register: pre_os_ver_cmd
      delegate_to: "{{ inventory_hostname }}"
      changed_when: false
      ignore_errors: true
#      ignore_unreachable: true
      check_mode: false
      tags: [ always, ALL_legacyos ]

    - name: "対象VMからPythonパスを取得"
      ansible.builtin.raw: "command -v python || command -v python2"
      register: pre_python_cmd
      delegate_to: "{{ inventory_hostname }}"
      changed_when: false
      failed_when: false
      ignore_errors: true
#      ignore_unreachable: true
      check_mode: false
      tags: [ always, ALL_legacyos ]

    - name: "取得した情報を変数としてセット"
      ansible.builtin.set_fact:
        os_major_version: "{{ (pre_os_ver_cmd.stdout | regex_search('release\\s+([0-9]+)', '\\1') | first | default('5')) if pre_os_ver_cmd.unreachable is not defined and pre_os_ver_cmd.rc | default(1) == 0 and 'release' in pre_os_ver_cmd.stdout | default('') else '5' }}"
        
        ansible_python_interpreter: "{{ (pre_python_cmd.stdout_lines | last | trim) if pre_python_cmd.unreachable is not defined and pre_python_cmd.rc | default(1) == 0 and pre_python_cmd.stdout_lines | default([]) | length > 0 else '/usr/bin/python' }}"
      tags: [ always, ALL_legacyos ]

    - name: "DEBUG: 取得したOSバージョンを確認"
      ansible.builtin.debug:
        msg:
          - "バージョン全体の情報: {{ pre_os_ver_cmd.stdout_lines | default([]) }}"
          - "抽出されたメジャーバージョン: [{{ os_major_version }}]"
      tags: [ always, ALL_legacyos ]


root@pve01:/etc/ansible/inventories# cat hosts_front | head -n 100
[nodes]
pve01
pve02
pve03
pve04

[vcenter65_migrationserver:children]
bl_www_1
bl_www_2
bl_www_3
bl_www_4
bl_www_5
gr_www_1
gr_www_2
gr_www_3
gr_www_4
gr_www_5
bl_cart_1
bl_cart_2
bl_cart_3
bl_cart_4
gr_cart_1
gr_cart_2
gr_cart_3
gr_cart_4
bl_kanri_1
bl_kanri_2
bl_kanri_3
gr_kanri_1
gr_kanri_2
gr_kanri_3
bl_cgi_1
bl_cgi_2
bl_cgi_3
bl_cgi_4
gr_cgi_1
gr_cgi_2
gr_cgi_3
gr_cgi_4
set5_0512_1
set5_0512_2


[vcenter70_migrationserver:children]
set0_bl_www_1
set0_bl_www_2
set0_bl_www_3
set0_gr_www_1
set0_gr_www_2
set0_gr_www_3
set0_bl_cart
set0_gr_cart
set0_bl_kanri_1
set0_bl_kanri_2
set0_gr_kanri_1
set0_gr_kanri_2
set0_bl_cgi_1
set0_bl_cgi_2
set0_bl_cgi_3
set0_gr_cgi_1
set0_gr_cgi_2
set0_gr_cgi_3



[set5_0512_1]


[set5_0512_2]
spbwww2524 vm_name=spbwww2524 ansible_host=10.200.145.63 vmid=1903 node_name=pve03
spbwww2525 vm_name=spbwww2525 ansible_host=10.200.145.64 vmid=1904 node_name=pve04
spbwww2526 vm_name=spbwww2526 ansible_host=10.200.145.65 vmid=1905 node_name=pve01


# lb_operation
[migrationserver_all]
#spbwww2521 vm_name=spbwww2521 ansible_host=10.200.145.60 vmid=1900 node_name=pve04
#spbwww2522 vm_name=spbwww2522 ansible_host=10.200.145.61 vmid=1901 node_name=pve01
#spbwww2523 vm_name=spbwww2523 ansible_host=10.200.145.62 vmid=1902 node_name=pve02
#spbwww2524 vm_name=spbwww2524 ansible_host=10.200.145.63 vmid=1903 node_name=pve03
#spbwww2525 vm_name=spbwww2525 ansible_host=10.200.145.64 vmid=1904 node_name=pve04
#spbwww2526 vm_name=spbwww2526 ansible_host=10.200.145.65 vmid=1905 node_name=pve01



[set0_bl_www_1]
spbwww0021 vm_name=spbwww0021 ansible_host=10.200.145.1 vmid=1000 node_name=pve01
spbwww0022 vm_name=spbwww0022 ansible_host=10.200.145.2 vmid=1001 node_name=pve02
spbwww0023 vm_name=spbwww0023 ansible_host=10.200.145.3 vmid=1002 node_name=pve03
spbwww0024 vm_name=spbwww0024 ansible_host=10.200.145.4 vmid=1003 node_name=pve04
spbwww0025 vm_name=spbwww0025 ansible_host=10.200.145.5 vmid=1004 node_name=pve01
spbwww0026 vm_name=spbwww0026 ansible_host=10.200.145.6 vmid=1005 node_name=pve02
spbwww0027 vm_name=spbwww0027 ansible_host=10.200.145.7 vmid=1006 node_name=pve03
spbwww0028 vm_name=spbwww0028 ansible_host=10.200.145.8 vmid=1007 node_name=pve04
spbwww0029 vm_name=spbwww0029 ansible_host=10.200.145.9 vmid=1008 node_name=pve01



root@pve01:/etc/ansible/inventories# ls
backup                hosts_api_es_indexer_legacyos  hosts_ex           hosts_front_legacyos              hosts_ssx2_legacyos
group_vars            hosts_db_gr_seed               hosts_ex_legacyos  hosts_shop_log_mail_dns           host_vars
hosts_api_es_indexer  hosts_db_gr_seed_legacyos      hosts_front        hosts_shop_log_mail_dns_legacyos


root@pve01:/etc/ansible/inventories/host_vars# cat localhost.yml 
---
ansible_connection: local
ansible_python_interpreter: /opt/ansible-vmw/bin/python


root@pve01:/etc/ansible/inventories/host_vars# cat pve01.yml 
---
ansible_host: 10.200.132.245
proxmox_api_host: 10.200.132.245
root@pve01:/etc/ansible/inventories/host_vars# cat pve02.yml 
---
ansible_host: 10.200.132.246
proxmox_api_host: 10.200.132.246
root@pve01:/etc/ansible/inventories/host_vars# cat pve03.yml 
---
ansible_host: 10.200.132.247
proxmox_api_host: 10.200.132.247
root@pve01:/etc/ansible/inventories/host_vars# cat pve04.yml 
---
ansible_host: 10.200.132.248
proxmox_api_host: 10.200.132.248


root@pve01:/etc/ansible/inventories/group_vars# ls
all.yml    vcenter65_legacyos_migrationserver.yml  vcenter70_legacyos_migrationserver.yml
nodes.yml  vcenter65_migrationserver.yml           vcenter70_migrationserver.yml


root@pve01:/etc/ansible/inventories/group_vars# cat all.yml 
# 全VM共通のSSH接続設定
ansible_user: "root"
ansible_password: "rP6@Sz3H"
#ansible_password: "caNsnFlz"
ansible_ssh_private_key_file: "~/.ssh/id_rsa"
root@pve01:/etc/ansible/inventories/group_vars# cat nodes.yml 
---
# Proxmoxノード共通のSSH接続情報
ansible_user: root
ansible_password: "caNsnFlz"
ansible_python_interpreter: /usr/bin/python3
root@pve01:/etc/ansible/inventories/group_vars# cat vcenter65_legacyos_migrationserver.yml 
---
# レガシーOSへのSSH接続時に古い暗号化方式を許可する
ansible_ssh_common_args: "-o KexAlgorithms=+diffie-hellman-group1-sha1 -o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o Ciphers=+3des-cbc"

# VMware vCenter,ESXi の接続情報
vcenter_host: "10.200.61.6"
vcenter_user: "administrator@vsphere.local"
vcenter_password: "c@NsnFlz4304"
vcenter_password_path: "/opt/vcenter-password_65.txt"
vmware_datacenter: "Shinkawa DC"
esxi_root_password: "caEnzFer_0"


# Proxmox APIの認証情報 (proxmox_kvmモジュール用)
proxmox_api_user: "root@pam"
proxmox_api_password: "caNsnFlz"
proxmox_bridge: vmbr0
proxmox_storage: "nas-vmstore"
root@pve01:/etc/ansible/inventories/group_vars# cat vcenter65_migrationserver.yml 
---
# VMware vCenter の接続情報
vcenter_host: "10.200.61.6"
vcenter_user: "administrator@vsphere.local"
vcenter_password: "c@NsnFlz4304"
vcenter_password_path: "/opt/vcenter-password_65.txt"
vmware_datacenter: "Shinkawa DC"

# Proxmox APIの認証情報 (proxmox_kvmモジュール用)
#proxmox_api_host: "10.200.132.60"
proxmox_api_user: "root@pam"
proxmox_api_password: "caNsnFlz"
proxmox_bridge: vmbr0


root@pve01:/etc/ansible/roles# ls
authorized_key  collect_vminfo_after   delete_vm     lb_operation        migration  poweron_vm   vmcreate
collect_nic     collect_vminfo_before  fix_yum_repo  legacyos_migration  mount      shutdown_vm



root@pve01:/etc/ansible/roles/authorized_key# ls
files  tasks
root@pve01:/etc/ansible/roles/authorized_key# 
root@pve01:/etc/ansible/roles/authorized_key# ls files/ansible_key 
files/ansible_key



root@pve01:/etc/ansible/roles/authorized_key/tasks# cat main.yml
- name: Copy public key
  ansible.posix.authorized_key:
    user: root
    state: present
    key: "{{ lookup('file', '/etc/ansible/roles/authorized_key/files/ansible_key') }}"
    
    
root@pve01:/etc/ansible/roles/collect_nic# ls
tasks  templates
root@pve01:/etc/ansible/roles/collect_nic# cd templates/
root@pve01:/etc/ansible/roles/collect_nic/templates# ls
70-persistent-net.rules.j2
root@pve01:/etc/ansible/roles/collect_nic/templates# less 70-persistent-net.rules.j2 
root@pve01:/etc/ansible/roles/collect_nic/templates# cat 70-persistent-net.rules.j2 
# This file was generated by Ansible for consistent NIC naming after migration.
# DO NOT EDIT THIS FILE MANUALLY.
{% for nic in nics_to_configure %}
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="{{ nic.mac }}", NAME="{{ nic.name }}"
{% endfor %}


root@pve01:/etc/ansible/roles/collect_nic/tasks# cat main.yml 
- name: NIC情報JSONファイルの存在を確認
  ansible.builtin.stat:
    path: "/tmp/{{ item }}_nic_data.json"
  loop: "{{ ansible_play_hosts }}"
  register: nic_file_stats
  delegate_to: localhost
  run_once: true

- name: "JSONファイルが存在しないVMのリストを作成"
  ansible.builtin.set_fact:
    vms_to_query: "{{ nic_file_stats.results | selectattr('stat.exists', 'equalto', false) | map(attribute='item') | list }}"
  run_once: true
  delegate_to: localhost

- name: PythonスクリプトをVM単位で実行しNIC名とMACアドレス情報を収集
  ansible.builtin.script:
    cmd: "/etc/ansible/generate_ansible_vars.py {{ item }} {{ hostvars[item].ansible_host }}"
  environment:
    # hostvars[item] から取得することで、ループ内の各VMが持つ変数を確実に参照する
    VCENTER_HOST: "{{ hostvars[item].vcenter_host | default(vcenter_host) }}"
    VCENTER_USER: "{{ hostvars[item].vcenter_user | default(vcenter_user) }}"
    VCENTER_PASSWORD: "{{ hostvars[item].vcenter_password | default(vcenter_password) }}"
    # ゲストOSの認証情報も hostvars から取得
    GUEST_USER: "{{ hostvars[item].ansible_user | default(ansible_user) }}"
    GUEST_PASSWORD: "{{ hostvars[item].ansible_password | default(ansible_password) }}"
  loop: "{{ vms_to_query }}"
  loop_control:
    label: "{{ item }}"
  register: python_result_each
  changed_when: true
  failed_when: false
  delegate_to: localhost
  run_once: true

- name: "DEBUG - 失敗VMの一覧"
  ansible.builtin.debug:
    msg: "FAILED: {{ item.item }} => rc={{ item.rc }}, stderr={{ item.stderr | default('') }}"
  loop: "{{ python_result_each.results | selectattr('rc', 'defined') | selectattr('rc','ne',0) | list }}"
  delegate_to: localhost
  run_once: true
  when:
    - hostvars[ansible_play_batch[0]].python_result_each is defined
    - hostvars[ansible_play_batch[0]].python_result_each.results is defined
    - (hostvars[ansible_play_batch[0]].python_result_each.results | selectattr('rc', 'defined') | selectattr('rc','ne',0) | list | length) > 0
    - not ansible_check_mode

- name: udevルールのディレクトリを作成
  ansible.builtin.file:
    path: /etc/udev/rules.d
    state: directory
    owner: root
    group: root
    mode: '0755'
  when: lookup('file', '/tmp/' + inventory_hostname + '_nic_data.json', errors='ignore')

- name: JSONファイルからNIC情報を読み込んで変数に登録
  ansible.builtin.set_fact:
    nics_to_configure: "{{ (lookup('file', '/tmp/' + inventory_hostname + '_nic_data.json') | from_json).nics_to_configure }}"
  when: lookup('file', '/tmp/' + inventory_hostname + '_nic_data.json', errors='ignore')

- name: templateファイルからudevルールを生成
  ansible.builtin.template:
    src: 70-persistent-net.rules.j2
    dest: /etc/udev/rules.d/70-persistent-net.rules
    owner: root
    group: root
    mode: '0644'
  vars:
    nics_to_configure: "{{ (lookup('file', '/tmp/' + inventory_hostname + '_nic_data.json') | from_json).nics_to_configure }}"
  when: lookup('file', '/tmp/' + inventory_hostname + '_nic_data.json', errors='ignore')

- name: Reload udev rules and trigger
  ansible.builtin.command: udevadm control --reload-rules
  changed_when: false
  when: lookup('file', '/tmp/' + inventory_hostname + '_nic_data.json', errors='ignore')

- name: Trigger udev events to apply new rules
  ansible.builtin.command: udevadm trigger
  changed_when: false
  when: lookup('file', '/tmp/' + inventory_hostname + '_nic_data.json', errors='ignore')



root@pve01:/etc/ansible/roles# cd collect_vminfo_before/
root@pve01:/etc/ansible/roles/collect_vminfo_before# ls
tasks
root@pve01:/etc/ansible/roles/collect_vminfo_before# cd tasks/
root@pve01:/etc/ansible/roles/collect_vminfo_before/tasks# ls
collect_vminfo_before.yml  collect_vminfo_legacyos_before.yml  main.yml
root@pve01:/etc/ansible/roles/collect_vminfo_before/tasks# cat main.yml 
---
# ==========================================
# 事前の情報収集 (Before)
# ==========================================
- name: 事前の情報収集 (systemd管理のVM用)
  ansible.builtin.include_tasks: collect_vminfo_before.yml
  when: >-
    'vcenter65_migrationserver' in group_names or
    'vcenter70_migrationserver' in group_names

- name: 事前の情報収集 (レガシーVM用)
  ansible.builtin.include_tasks: collect_vminfo_legacyos_before.yml
  when: >-
    'vcenter65_legacyos_migrationserver' in group_names or
    'vcenter70_legacyos_migrationserver' in group_names

root@pve01:/etc/ansible/roles/collect_vminfo_before/tasks# cat collect_vminfo_before.yml 
- name: "サーバーごとの結果出力用ディレクトリをAnsible実行ノードに作成"
  ansible.builtin.file:
    path: "/etc/ansible/vminfo_results/{{ inventory_hostname }}"
    state: directory
  delegate_to: localhost

- name: "ディスク一覧(df -h)の取得"
  ansible.builtin.shell: df -h
  register: disk_result

- name: "ディスク一覧をファイルに保存"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ disk_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_before.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "サービス一覧の取得 (systemd: CentOS 7+, AlmaLinux等)"
  ansible.builtin.shell: systemctl list-unit-files --type=service --no-pager || true
  register: service_result

- name: "サービス一覧をファイルに保存"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ service_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_before.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "プロセス一覧の取得"
  ansible.builtin.shell: ps -eo user,args --sort=user,args | grep -v "\.ansible/tmp" || true
  register: process_result

- name: "プロセス一覧をファイルに保存"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ process_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_before.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "NFS接続情報の取得 (netstat TCP 2049)"
  ansible.builtin.shell: >-
    netstat -an | awk '$4 ~ /:2049$/ { sub(/:[0-9]+$/, "", $5); print $4, $5, $6 }' | sort -u || true
  register: nfs_netstat_result
  failed_when: false
  changed_when: false

- name: "NFS接続情報をファイルに保存 (NFSポート待機・接続がある場合のみ)"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ nfs_netstat_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_nfs_netstat_before.txt"
  delegate_to: localhost
  when:
    - not ansible_check_mode
    - nfs_netstat_result is defined
    - nfs_netstat_result.stdout is defined
    - "':2049' in nfs_netstat_result.stdout"
root@pve01:/etc/ansible/roles/collect_vminfo_before/tasks# cat collect_vminfo_legacyos_before.yml 
- name: "サーバーごとの結果出力用ディレクトリをAnsible実行ノードに作成"
  ansible.builtin.file:
    path: "/etc/ansible/vminfo_results/{{ inventory_hostname }}"
    state: directory
  delegate_to: localhost

- name: "ディスク一覧(df -h)の取得"
  ansible.builtin.raw: df -h
  register: disk_result

- name: "ディスク一覧のファイルに保存"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ disk_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_before.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "サービス一覧の取得(CentOS 4/5/6)"
  ansible.builtin.raw: chkconfig --list | grep "3:on" || true
  register: service_result

- name: "サービス一覧をファイルに保存"
  ansible.builtin.copy:
    # contentの先頭に実行日時を追加する
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ service_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_before.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "プロセス一覧の取得"
  ansible.builtin.raw: ps -eo user,args --sort=user,args | grep -v "\.ansible/tmp" || true
  register: process_result

- name: "プロセス一覧をファイルに保存"
  ansible.builtin.copy:
    # contentの先頭に実行日時を追加する
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ process_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_before.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "NFS接続情報の取得 (netstat TCP 2049)"
  ansible.builtin.raw: >-
    netstat -an | awk '$4 ~ /:2049$/ { sub(/:[0-9]+$/, "", $5); print $4, $5, $6 }' | sort -u || true
  register: nfs_netstat_result
  failed_when: false
  changed_when: false

- name: "NFS接続情報をファイルに保存 (NFSポート待機・接続がある場合のみ)"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ nfs_netstat_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_nfs_netstat_before.txt"
  delegate_to: localhost
  when:
    - not ansible_check_mode
    - nfs_netstat_result is defined
    - nfs_netstat_result.stdout is defined
    - "':2049' in nfs_netstat_result.stdout"
    

root@pve01:/etc/ansible/roles/collect_vminfo_after/tasks# cat main.yml 
---
# ==========================================
# 事後の情報収集＋Diff (After)
# ==========================================
- name: 事後の情報収集＋Diff (systemd管理のVM用)
  ansible.builtin.include_tasks: collect_vminfo_after.yml
  when: >-
    'vcenter65_migrationserver' in group_names or
    'vcenter70_migrationserver' in group_names
  tags:
    - vminfo_after
    - never

- name: 事後の情報収集＋Diff (レガシーVM用)
  ansible.builtin.include_tasks: collect_vminfo_legacyos_after.yml
  when: >-
    'vcenter65_legacyos_migrationserver' in group_names or
    'vcenter70_legacyos_migrationserver' in group_names
  tags:
    - vminfo_after
    - never

root@pve01:/etc/ansible/roles/collect_vminfo_after/tasks# cat collect_vminfo_after.yml 
- name: "サーバーごとの結果出力用ディレクトリをAnsible実行ノードに作成"
  ansible.builtin.file:
    path: "/etc/ansible/vminfo_results/{{ inventory_hostname }}"
    state: directory
  delegate_to: localhost

# ==========================================
# 1. After情報の取得と保存
# ==========================================
- name: "ディスク使用量(df -h)の取得"
  ansible.builtin.shell: df -h
  register: disk_result_after

- name: "ディスク使用量をファイルに保存"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ disk_result_after.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_after.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "サービス一覧の取得 (systemd: CentOS 7+, AlmaLinux等)"
  ansible.builtin.shell: systemctl list-unit-files --type=service --no-pager || true
  register: service_result_after

- name: "サービス一覧をファイルに保存"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ service_result_after.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_after.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "プロセス一覧の取得"
  ansible.builtin.shell: ps -eo user,args --sort=user,args | grep -v "\.ansible/tmp" || true
  register: process_result

- name: "プロセス一覧をファイルに保存"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ process_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_after.txt"
  delegate_to: localhost
  when: not ansible_check_mode

# ==========================================
# 2. Before / After の差分(Diff)の取得と保存
# ==========================================
- name: "ディスク使用量の差分比較"
  ansible.builtin.shell: |
    diff -u -w -I '^========== 取得日時:' "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_before.txt" "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_after.txt" || true
  register: diff_disk
  delegate_to: localhost

- name: "ディスク使用量の差分結果を保存"
  ansible.builtin.copy:
    content: |
      {% if diff_disk.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_disk.stdout }}
      {% endif %}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_diff.txt"
  delegate_to: localhost

- name: "サービス一覧の差分比較"
  ansible.builtin.shell: |
    diff -u -w -I '^========== 取得日時:' "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_before.txt" "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_after.txt" || true
  register: diff_services
  delegate_to: localhost

- name: "サービス一覧の差分結果を保存"
  ansible.builtin.copy:
    content: |
      {% if diff_services.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_services.stdout }}
      {% endif %}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_diff.txt"
  delegate_to: localhost

- name: "プロセス一覧の差分比較"
  ansible.builtin.shell: |
    diff -u -I '^========== 取得日時:' \
      <(grep -v " \[" "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_before.txt") \
      <(grep -v " \[" "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_after.txt") || true
  args:
    executable: /bin/bash
  register: diff_processes
  delegate_to: localhost

- name: "プロセス一覧の差分結果を保存"
  ansible.builtin.copy:
    content: |
      {% if diff_processes.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_processes.stdout }}
      {% endif %}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_diff.txt"
  delegate_to: localhost

# ==========================================
# 3. 差分(Diff)結果の標準出力（コンソール表示）
# ==========================================
- name: "【結果表示】ディスク使用量の差分"
  ansible.builtin.debug:
    msg: |
      === [ {{ inventory_hostname }} ] ディスク使用量の差分 ===
      {% if diff_disk.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_disk.stdout }}
      {% endif %}
  when: not ansible_check_mode

- name: "【結果表示】サービス一覧の差分"
  ansible.builtin.debug:
    msg: |
      === [ {{ inventory_hostname }} ] サービス一覧の差分 ===
      {% if diff_services.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_services.stdout }}
      {% endif %}
  when: not ansible_check_mode

- name: "【結果表示】プロセス一覧の差分"
  ansible.builtin.debug:
    msg: |
      === [ {{ inventory_hostname }} ] プロセス一覧の差分 ===
      {% if diff_processes.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_processes.stdout }}
      {% endif %}
  when: not ansible_check_mode

- name: "処理完了メッセージ"
  ansible.builtin.debug:
    msg: "VM {{ vmid }} ({{ inventory_hostname }}) の移行が完了しました。差分の結果を確認して問題なければLBへの切り戻しを行ってください。"
  when: not ansible_check_mode
root@pve01:/etc/ansible/roles/collect_vminfo_after/tasks# cat collect_vminfo_legacyos_after.yml 
- name: "サーバーごとの結果出力用ディレクトリをAnsible実行ノードに作成"
  ansible.builtin.file:
    path: "/etc/ansible/vminfo_results/{{ inventory_hostname }}"
    state: directory
  delegate_to: localhost

# ==========================================
# 1. After情報の取得と保存
# ==========================================
- name: "ディスク一覧(df -h)の取得 (After)"
  ansible.builtin.raw: df -h
  register: disk_result_after

- name: "ディスク一覧をファイルに保存 (After)"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ disk_result_after.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_after.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "サービス一覧の取得 (SysVinit: CentOS 5/6) (After)"
  ansible.builtin.raw: chkconfig --list | grep "3:on" || true
  register: service_result_after

- name: "サービス一覧をファイルに保存 (After)"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ service_result_after.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_after.txt"
  delegate_to: localhost
  when: not ansible_check_mode

#- name: "プロセス一覧の取得 (After)"
#  ansible.builtin.raw: ps aux --sort=-%mem
#  register: process_result_after

- name: "プロセス一覧の取得 (After)"
  ansible.builtin.raw: ps -eo user,args --sort=user,args | grep -v "\.ansible/tmp" || true
  register: process_result

- name: "プロセス一覧をファイルに保存 (After)"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ process_result.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_after.txt"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "NFS接続情報の取得 (netstat TCP 2049) (After) (raw)"
  ansible.builtin.raw: >-
    netstat -an | awk '$4 ~ /:2049$/ { sub(/:[0-9]+$/, "", $5); print $4, $5, $6 }' | sort -u || true
  register: nfs_netstat_result_after
  failed_when: false
  changed_when: false

- name: "NFS接続情報をファイルに保存 (NFSポート待機・接続がある場合のみ) (After)"
  ansible.builtin.copy:
    content: |
      ========== 取得日時: {{ lookup('pipe', 'date "+%Y/%m/%d %H:%M:%S"') }} ==========
      {{ nfs_netstat_result_after.stdout }}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_nfs_netstat_after.txt"
  delegate_to: localhost
  when:
    - not ansible_check_mode
    - nfs_netstat_result_after is defined
    - nfs_netstat_result_after.stdout is defined
    - "':2049' in nfs_netstat_result_after.stdout"

# ==========================================
# 2. Before / After の差分(Diff)の取得と保存
# ==========================================
- name: "ディスク一覧の差分比較"
  ansible.builtin.shell: |
    diff -u -w -I '^========== 取得日時:' "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_before.txt" "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_after.txt" || true
  register: diff_disk
  delegate_to: localhost

- name: "ディスク一覧の差分結果を保存"
  ansible.builtin.copy:
    content: |
      {% if diff_disk.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_disk.stdout }}
      {% endif %}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_disk_diff.txt"
  delegate_to: localhost

- name: "サービス一覧の差分比較"
  ansible.builtin.shell: |
    diff -u -w -I '^========== 取得日時:' "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_before.txt" "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_after.txt" || true
  register: diff_services
  delegate_to: localhost

- name: "サービス一覧の差分結果を保存"
  ansible.builtin.copy:
    content: |
      {% if diff_services.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_services.stdout }}
      {% endif %}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_services_diff.txt"
  delegate_to: localhost

- name: "プロセス一覧の差分比較"
  ansible.builtin.shell: |
    diff -u -I '^========== 取得日時:' \
      <(grep -v " \[" "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_before.txt") \
      <(grep -v " \[" "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_after.txt") || true
  args:
    executable: /bin/bash
  register: diff_processes
  delegate_to: localhost

- name: "プロセス一覧の差分結果を保存"
  ansible.builtin.copy:
    content: |
      {% if diff_processes.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_processes.stdout }}
      {% endif %}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_processes_diff.txt"
  delegate_to: localhost

- name: "NFS接続(netstat)のBeforeファイルが存在するか確認 (NFSサーバー判定)"
  ansible.builtin.stat:
    path: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_nfs_netstat_before.txt"
  register: nfs_netstat_before_file
  delegate_to: localhost

- name: "NFS接続(netstat)の差分比較"
  ansible.builtin.shell: |
    diff -u -I '^========== 取得日時:' "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_nfs_netstat_before.txt" "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_nfs_netstat_after.txt" || true
  register: diff_nfs_netstat
  delegate_to: localhost
  when: nfs_netstat_before_file.stat.exists

- name: "NFS接続(netstat)の差分結果を保存"
  ansible.builtin.copy:
    content: |
      {% if diff_nfs_netstat.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_nfs_netstat.stdout }}
      {% endif %}
    dest: "/etc/ansible/vminfo_results/{{ inventory_hostname }}/{{ inventory_hostname }}_nfs_netstat_diff.txt"
  delegate_to: localhost
  when: nfs_netstat_before_file.stat.exists

# ==========================================
# 3. 差分(Diff)結果の標準出力（コンソール表示）
# ==========================================
- name: "【結果表示】ディスク一覧の差分"
  ansible.builtin.debug:
    msg: |
      === [ {{ inventory_hostname }} ] ディスク使用量の差分 ===
      {% if diff_disk.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_disk.stdout }}
      {% endif %}
  when: not ansible_check_mode

- name: "【結果表示】サービス一覧の差分"
  ansible.builtin.debug:
    msg: |
      === [ {{ inventory_hostname }} ] サービス一覧の差分 ===
      {% if diff_services.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_services.stdout }}
      {% endif %}
  when: not ansible_check_mode

- name: "【結果表示】プロセス一覧の差分"
  ansible.builtin.debug:
    msg: |
      === [ {{ inventory_hostname }} ] プロセス一覧の差分 ===
      {% if diff_processes.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_processes.stdout }}
      {% endif %}
  when: not ansible_check_mode

- name: "【結果表示】NFS接続(netstat)の差分"
  ansible.builtin.debug:
    msg: |
      === [ {{ inventory_hostname }} ] NFS接続(netstat)の差分 ===
      {% if diff_nfs_netstat.stdout == "" %}
      差分はありません。
      {% else %}
      {{ diff_nfs_netstat.stdout }}
      {% endif %}
  when:
    - not ansible_check_mode
    - nfs_netstat_before_file.stat.exists

- name: "処理完了メッセージ"
  ansible.builtin.debug:
    msg: "VM {{ vmid }} ({{ inventory_hostname }}) の移行が完了しました。差分の結果を確認して問題なければLBへの切り戻しを行ってください。"
  when: not ansible_check_mode
  
  
root@pve01:/etc/ansible/roles/fix_yum_repo/tasks# ls
main.yml
root@pve01:/etc/ansible/roles/fix_yum_repo/tasks# 
root@pve01:/etc/ansible/roles/fix_yum_repo/tasks# 
root@pve01:/etc/ansible/roles/fix_yum_repo/tasks# cat main.yml 
- name: Gather facts for CentOS/AlmaLinux check
  ansible.builtin.setup:
  when: ansible_distribution is not defined

# =========================================================
# 共通: OSごとの設定ファイルパスを判定
# =========================================================
- name: Set config path based on OS
  ansible.builtin.set_fact:
    pkg_conf_path: "{{ '/etc/dnf/dnf.conf' if ansible_distribution == 'AlmaLinux' else '/etc/yum.conf' }}"

# =========================================================
# 共通: yum.conf / dnf.conf へのプロキシ設定追加
# =========================================================
- name: Add proxy setting to package manager config
  ansible.builtin.ini_file:
    path: "{{ pkg_conf_path }}"
    section: main
    option: proxy
    value: "http://10.200.3.130:8080"
    backup: yes
  when: >
    (ansible_distribution == 'CentOS' and ansible_distribution_major_version == '7') or
    (ansible_distribution == 'AlmaLinux')

# =========================================================
# AlmaLinux 専用: 指定以外のリポジトリを無効化
# =========================================================
- name: Find non-base repository files (AlmaLinux only)
  ansible.builtin.find:
    paths: /etc/yum.repos.d/
    patterns: '*.repo'
    excludes:
      # 環境によって混在する可能性のあるベースリポジトリをすべて除外リストに入れます
      - 'almalinux.repo'
      - 'almalinux-baseos.repo'
      - 'almalinux-appstream.repo'
      # - 'almalinux-extras.repo'   # 必要であればコメントアウト外す
  register: almalinux_extra_repos
  when:
    - ansible_distribution == 'AlmaLinux'

- name: Disable non-base repositories by renaming them (AlmaLinux only)
  ansible.builtin.command: "mv {{ item.path }} {{ item.path }}.disabled"
  loop: "{{ almalinux_extra_repos.files | default([]) }}"
  when:
    - ansible_distribution == 'AlmaLinux'
    - almalinux_extra_repos.matched > 0
  changed_when: true

# =========================================================
# AlmaLinux 専用: 存在するベースリポジトリの検索
# =========================================================
- name: Find existing base repository files (AlmaLinux only)
  ansible.builtin.find:
    paths: /etc/yum.repos.d/
    # 処理対象としたいベースリポジトリの候補をリストアップします
    patterns:
      - 'almalinux.repo'
      - 'almalinux-baseos.repo'
      - 'almalinux-appstream.repo'
  register: almalinux_base_repos
  when: ansible_distribution == 'AlmaLinux'

# =========================================================
# AlmaLinux 専用: mirrorlistを無効化し、baseurlを有効化
# =========================================================
- name: Comment out 'mirrorlist' in AlmaLinux repos
  ansible.builtin.replace:
    # 検索でヒットした（実在する）ファイルのパスを動的に指定します
    path: "{{ item.path }}"
    regexp: '^mirrorlist='
    replace: '#mirrorlist='
  loop: "{{ almalinux_base_repos.files | default([]) }}"
  when: ansible_distribution == 'AlmaLinux'

- name: Uncomment 'baseurl' in AlmaLinux repos
  ansible.builtin.replace:
    # 検索でヒットした（実在する）ファイルのパスを動的に指定します
    path: "{{ item.path }}"
    regexp: '^#\s*baseurl='
    replace: 'baseurl='
  loop: "{{ almalinux_base_repos.files | default([]) }}"
  when: ansible_distribution == 'AlmaLinux'

# =========================================================
# 以降はすべて CentOS 7 専用の処理
# =========================================================
- name: Find non-base repository files (CentOS 7 only)
  ansible.builtin.find:
    paths: /etc/yum.repos.d/
    patterns: '*.repo'
    excludes: 'CentOS-Base.repo'
  register: extra_repos
  when:
    - ansible_distribution == 'CentOS'
    - ansible_distribution_major_version == '7'

- name: Disable non-base repositories by renaming them (CentOS 7 only)
  ansible.builtin.command: "mv {{ item.path }} {{ item.path }}.disabled"
  loop: "{{ extra_repos.files | default([]) }}"
  when:
    - ansible_distribution == 'CentOS'
    - ansible_distribution_major_version == '7'
    - extra_repos.matched > 0
  changed_when: true

- name: 1. Backup /etc/yum.repos.d/CentOS-Base.repo (CentOS 7 only)
  ansible.builtin.copy:
    src: /etc/yum.repos.d/CentOS-Base.repo
    dest: /etc/yum.repos.d/CentOS-Base.repo.bak
    remote_src: yes
    force: no
    owner: root
    group: root
    mode: '0644'
  when:
    - ansible_distribution == 'CentOS'
    - ansible_distribution_major_version == '7'

- name: 2a. Comment out the 'mirrorlist' lines (CentOS 7 only)
  ansible.builtin.replace:
    path: /etc/yum.repos.d/CentOS-Base.repo
    regexp: '^mirrorlist='
    replace: '#mirrorlist='
  register: mirrorlist_result
  when:
    - ansible_distribution == 'CentOS'
    - ansible_distribution_major_version == '7'

- name: 2b. Set 'baseurl' to vault.centos.org (CentOS 7 only)
  ansible.builtin.replace:
    path: /etc/yum.repos.d/CentOS-Base.repo
    regexp: '^#baseurl=http://mirror.centos.org'
    replace: 'baseurl=http://vault.centos.org'
  register: baseurl_result
  when:
    - ansible_distribution == 'CentOS'
    - ansible_distribution_major_version == '7'

# =========================================================
# 共通: yum キャッシュのクリア
# =========================================================
- name: 3. Clean yum cache (if repo changed)
  ansible.builtin.command: yum clean all
  when:
    - >
      (ansible_distribution == 'CentOS' and ansible_distribution_major_version == '7') or
      (ansible_distribution == 'AlmaLinux')
    - mirrorlist_result.changed | default(false) or baseurl_result.changed | default(false)



root@pve01:/etc/ansible/roles# cd migration/
root@pve01:/etc/ansible/roles/migration# ls
tasks
root@pve01:/etc/ansible/roles/migration# cd tasks/
root@pve01:/etc/ansible/roles/migration/tasks# ls
main.yml
root@pve01:/etc/ansible/roles/migration/tasks# cat main.yml 
# ----------------------------------------
# 事前準備
# ----------------------------------------
- name: vCenterパスワードファイルを作成
  ansible.builtin.copy:
    content: "{{ vcenter_password }}"
    dest: "{{ vcenter_password_path }}"
    mode: '0600'
  no_log: true
  delegate_to: localhost

- name: パスワードファイルのパスを変数に格納
  ansible.builtin.set_fact:
    password_file_path: "{{ vcenter_password_path }}"

- name: vCenterのSSL接続情報を取得
  ansible.builtin.shell:
    cmd: "openssl s_client -connect {{ vcenter_host }}:443 </dev/null 2>/dev/null | openssl x509 -in /dev/stdin -fingerprint -sha1 -noout | cut -d '=' -f 2"
  register: vcenter_thumbprint
  delegate_to: localhost
  changed_when: false

- name: VMの詳細情報を取得 (クラスタ名・電源状態・ホスト名)
  community.vmware.vmware_guest_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    validate_certs: no
    name: "{{ inventory_hostname }}"
  register: vm_guest_info
  delegate_to: localhost

- name: VMDKファイルのパスから移行先ストレージを判定しリスト化
  ansible.builtin.set_fact:
    target_storages: >-
      {%- set results = [] -%}
      {# ▼ VMwareのディスク一覧を抽出し、名前順でソート #}
      {%- set vmdks = vm_guest_info.instance.hw_files | select('search', '\.vmdk$') | reject('search', '-[0-9]{6}\.vmdk$') | list | sort -%}
      {%- for path in vmdks -%}
        {%- set ds_name = (path | regex_replace('^\\[(.*?)\\] .*$', '\\1')) -%}
        {%- set is_nas = ('nas' in ds_name | lower) -%}
        {%- if is_nas -%}
          {%- set _ = results.append('nas-vmstore') -%}
        {%- else -%}
          {%- set _ = results.append('local-lvm') -%}
        {%- endif -%}
      {%- endfor -%}
      {{ results }}

- name: "DEBUG: 判定されたストレージリストを出力"
  ansible.builtin.debug:
    var: target_storages

- name: 接続URIとホスト変数を設定
  ansible.builtin.set_fact:
    host: "{{ vm_guest_info.instance.hw_esxi_host }}"
    # クラスタの有無に応じてURIを切り替え
    vcenter_connection_uri: >-
      {% if vm_guest_info.instance.hw_cluster is defined and vm_guest_info.instance.hw_cluster -%}
      vpx://{{ vcenter_user | urlencode }}@{{ vcenter_host }}/Shinkawa%20DC/host/{{ vm_guest_info.instance.hw_cluster }}/{{ vm_guest_info.instance.hw_esxi_host }}/?no_verify=1
      {%- else -%}
      vpx://{{ vcenter_user | urlencode }}@{{ vcenter_host }}/Shinkawa%20DC/host/{{ vm_guest_info.instance.hw_esxi_host }}/?no_verify=1
      {%- endif %}

- name: 対象VMが電断状態か確認
  ansible.builtin.assert:
    that:
      - vm_guest_info.instance is defined
      - vm_guest_info.instance.hw_power_status == 'poweredOff'
    fail_msg: >-
      VM '{{ inventory_hostname }}' is not in poweredOff state.
      Current state: {{ vm_guest_info.instance.hw_power_status | default('VM Not Found') }}
    success_msg: "VM '{{ inventory_hostname }}' is powered off."
  delegate_to: localhost
  when: not ansible_check_mode

- name: 対象VMのスナップショット情報を取得
  community.vmware.vmware_guest_snapshot_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    validate_certs: no
    datacenter: "{{ vmware_datacenter }}"
    uuid: "{{ vm_guest_info.instance.hw_product_uuid }}"
  register: snapshot_info
  delegate_to: localhost

- name: スナップショットが存在する場合はすべて削除（統合）する
  community.vmware.vmware_guest_snapshot:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    validate_certs: no
    datacenter: "{{ vmware_datacenter }}"
    uuid: "{{ vm_guest_info.instance.hw_product_uuid }}"
    state: remove_all
  delegate_to: localhost
  when:
    - snapshot_info.guest_snapshots is defined
    - snapshot_info.guest_snapshots.current_snapshot is defined

# ----------------------------------------
# 各VMの一時ディレクトリ（TMPDIR）
# ----------------------------------------
- name: ディスクイメージの格納用ディレクトリ作成
  file:
    path: "/mnt/pve/nas-vmstore/tmp/v2vtmp-{{ vm_name }}"
    state: directory
    mode: '0755'
  delegate_to: localhost

# ----------------------------------------
# virt-v2v 実行
# ----------------------------------------
- name: virt-v2v 実行
  shell: |
    TMPDIR=/mnt/pve/nas-vmstore/tmp/v2vtmp-{{ vm_name }} \
    LIBGUESTFS_BACKEND=direct /usr/bin/virt-v2v -v -x \
      -i libvirt \
      -ic "{{ vcenter_connection_uri }}" \
      -it vddk \
      -io vddk-libdir=/opt/vddk/vmware-vix-disklib-distrib \
       -io vddk-thumbprint="{{ vcenter_thumbprint.stdout | trim }}"\
      --password-file "{{ password_file_path }}" \
      -o local -of raw -oa sparse \
      -os /mnt/pve/nas-vmstore/tmp/v2vtmp-{{ vm_name }} \
      {{ inventory_hostname }}
  args:
    executable: /bin/bash
  register: virtv2v_result
  delegate_to: localhost



root@pve01:/etc/ansible/roles/legacyos_migration# cd tasks/
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# ls
collect_nic.yml  exec_migration.yml  import_disk.yml  import_disk.yml.bk  main.yml  main.yml.bk  vmcreate.yml
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# 
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# 
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# 
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# 
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# 
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# cat collect_nic.yml 
- name: NIC情報JSONファイルの存在を確認
  ansible.builtin.stat:
    path: "/tmp/{{ item }}_nic_data.json"
  loop: "{{ ansible_play_hosts }}"
  register: nic_file_stats
  delegate_to: localhost
  run_once: true

- name: "JSONファイルが存在しないVMのリストを作成"
  ansible.builtin.set_fact:
    vms_to_query: "{{ nic_file_stats.results | selectattr('stat.exists', 'equalto', false) | map(attribute='item') | list }}"
  run_once: true
  delegate_to: localhost

- name: PythonスクリプトをVM単位で実行しNIC名とMACアドレス情報を収集
  ansible.builtin.script:
    cmd: "/etc/ansible/generate_ansible_vars.py {{ item }} {{ hostvars[item].ansible_host }}"
  environment:
    VCENTER_HOST: "{{ vcenter_host }}"
    VCENTER_USER: "{{ vcenter_user }}"
    VCENTER_PASSWORD: "{{ vcenter_password }}"
    GUEST_USER: "{{ ansible_user }}"
    GUEST_PASSWORD: "{{ ansible_password }}"
  loop: "{{ vms_to_query }}"
  loop_control:
    label: "{{ item }}"
  register: python_result_each
  changed_when: true
  failed_when: false
  delegate_to: localhost
  when: vms_to_query | length > 0
  run_once: true

- name: "DEBUG - 失敗VMの一覧"
  ansible.builtin.debug:
    msg: "FAILED: {{ item.item }} => rc={{ item.rc }}, stderr={{ item.stderr | default('') }}"
  loop: "{{ python_result_each.results | selectattr('rc', 'defined') | selectattr('rc','ne',0) | list }}"
  delegate_to: localhost
  run_once: true
  when:
    - hostvars[ansible_play_batch[0]].python_result_each is defined
    - hostvars[ansible_play_batch[0]].python_result_each.results is defined
    - (hostvars[ansible_play_batch[0]].python_result_each.results | selectattr('rc', 'defined') | selectattr('rc','ne',0) | list | length) > 0
    - not ansible_check_mode
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# cat exec_migration.yml 
---
# -------------------------------------------------------
# 1. VM情報の取得と停止処理
# -------------------------------------------------------
- name: VMの電源状態を確認
  community.vmware.vmware_guest_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    validate_certs: no
    name: "{{ inventory_hostname }}"
  register: vm_initial_info
  delegate_to: localhost

# ▼CentOS 4 の場合の処理
- name: "CentOS 4: ネットワーク設定の引継ぎ(e1000)と、kudzu の無効化"
  ansible.builtin.raw: |
    if [ -f /etc/modprobe.conf ]; then
      [ ! -f /etc/modprobe.conf.bak_v2v ] && cp -p /etc/modprobe.conf /etc/modprobe.conf.bak_v2v
      sed -i 's/^alias eth\([0-9]*\) .*/alias eth\1 e1000/' /etc/modprobe.conf
    fi
    chkconfig kudzu off
  delegate_to: "{{ inventory_hostname }}"
  when:
    - os_major_version | default('') | string == '4'
    - vm_initial_info.instance.hw_power_status == 'poweredOn'

# ▼CentOS 5 の場合の処理
- name: "CentOS 5: VirtIO対応と各種設定の最適化"
  ansible.builtin.raw: |
    # 1. modprobe.conf
    if [ -f /etc/modprobe.conf ]; then
      [ ! -f /etc/modprobe.conf.bak_v2v ] && cp -p /etc/modprobe.conf /etc/modprobe.conf.bak_v2v
      sed -i -e 's/^alias eth\([0-9]*\) .*/alias eth\1 virtio_net/' -e '/virtio_scsi/d' /etc/modprobe.conf
    fi

    # 2. ifcfg-* 
    mkdir -p /etc/sysconfig/network-scripts/bak_v2v
    for f in /etc/sysconfig/network-scripts/ifcfg-*; do
      # ディレクトリ自身や、存在しないファイルはスキップ
      [ ! -f "$f" ] && continue
      fname=$(basename "$f")
      # 初回のみバックアップをサブディレクトリに取得
      [ ! -f "/etc/sysconfig/network-scripts/bak_v2v/${fname}" ] && cp -p "$f" "/etc/sysconfig/network-scripts/bak_v2v/${fname}"
      # 本体の書き換え
      sed -i -e '/^HWADDR/d' -e '/^MACADDR/d' "$f"
    done

    # 3. 70-persistent-net.rules
    if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
      mv -f /etc/udev/rules.d/70-persistent-net.rules /etc/udev/rules.d/70-persistent-net.rules.bak_v2v
    fi

    # 4. fstab
    if [ -f /etc/fstab ]; then
      [ ! -f /etc/fstab.bak_v2v ] && cp -p /etc/fstab /etc/fstab.bak_v2v
      sed -i 's/\/dev\/sd\([a-z]\)/\/dev\/vd\1/g' /etc/fstab
    fi

    # 5. DRBD configs
    if [ -f /etc/drbd.conf ]; then
      [ ! -f /etc/drbd.conf.bak_v2v ] && cp -p /etc/drbd.conf /etc/drbd.conf.bak_v2v
      sed -i 's/\/dev\/sd\([a-z]\)/\/dev\/vd\1/g' /etc/drbd.conf
    fi
    for f in /etc/drbd.d/*.res; do
      case "$f" in
        *.bak_v2v|*\*) continue ;;
      esac
      [ ! -f "$f" ] && continue
      [ ! -f "${f}.bak_v2v" ] && cp -p "$f" "${f}.bak_v2v"
      sed -i 's/\/dev\/sd\([a-z]\)/\/dev\/vd\1/g' "$f"
    done

    # 6. initrd
    KVER=$(uname -r)
    [ ! -f /boot/initrd-${KVER}.img.bak_v2v ] && cp -p /boot/initrd-${KVER}.img /boot/initrd-${KVER}.img.bak_v2v
    mkinitrd -f --with=virtio_pci --with=virtio_ring --with=virtio_blk --with=virtio_net /boot/initrd-${KVER}.img ${KVER}

    # 7. kudzu
    chkconfig kudzu off
  delegate_to: "{{ inventory_hostname }}"
  when:
    - os_major_version | default('') | string == '5'
    - vm_initial_info.instance.hw_power_status == 'poweredOn'


# ▼CentOS 6 の場合の処理
- name: "CentOS 6: VirtIO対応と各種設定の最適化"
  ansible.builtin.raw: |
    # 1. ifcfg-*
    mkdir -p /etc/sysconfig/network-scripts/bak_v2v
    for f in /etc/sysconfig/network-scripts/ifcfg-*; do
      [ ! -f "$f" ] && continue
      fname=$(basename "$f")
      # 初回のみバックアップをサブディレクトリに取得
      [ ! -f "/etc/sysconfig/network-scripts/bak_v2v/${fname}" ] && cp -p "$f" "/etc/sysconfig/network-scripts/bak_v2v/${fname}"
      # 本体の書き換え
      sed -i -e '/^HWADDR/d' -e '/^MACADDR/d' -e '/^UUID/d' "$f"
    done

    # 2. 70-persistent-net.rules
    if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
      mv -f /etc/udev/rules.d/70-persistent-net.rules /etc/udev/rules.d/70-persistent-net.rules.bak_v2v
    fi

    # 3. initramfs
    KVER=$(uname -r)
    [ ! -f /tmp/old_initramfs-${KVER}.img.bak ] && cp -p /boot/initramfs-${KVER}.img /tmp/old_initramfs-${KVER}.img.bak
    dracut -f --add-drivers "virtio virtio_ring virtio_pci virtio_scsi virtio_blk virtio_net" /tmp/new_initramfs-${KVER}.img ${KVER}
    mv -f /tmp/new_initramfs-${KVER}.img /boot/initramfs-${KVER}.img
  delegate_to: "{{ inventory_hostname }}"
  when:
    - os_major_version | default('') | string == '6'
    - vm_initial_info.instance.hw_power_status == 'poweredOn'

- name: "対象VMの停止 (VMwareTools稼働時はゲストシャットダウン)"
  community.vmware.vmware_guest:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    name: "{{ inventory_hostname }}"
    state: shutdown-guest
    validate_certs: no
  delegate_to: localhost
  when:
    - vm_initial_info.instance.hw_power_status == 'poweredOn'
    - vm_initial_info.instance.guest_tools_status == 'guestToolsRunning'

- name: "対象VMの停止 (VMwareTools非実行時はSSH経由でシャットダウン)"
  ansible.builtin.raw: "shutdown -h now"
  ignore_errors: true
  delegate_to: "{{ inventory_hostname }}"
  when:
    - vm_initial_info.instance.hw_power_status == 'poweredOn'
    - vm_initial_info.instance.guest_tools_status != 'guestToolsRunning'

- name: "対象VMが完全に停止するまで待機"
  community.vmware.vmware_guest_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    name: "{{ inventory_hostname }}"
    validate_certs: no
  register: vm_wait_info 
  until: "vm_wait_info.instance.hw_power_status == 'poweredOff'"
  retries: 30
  delay: 10
  delegate_to: localhost
  when: not ansible_check_mode

- name: 対象VMのスナップショット情報を取得
  community.vmware.vmware_guest_snapshot_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    datacenter: "{{ vmware_datacenter }}"
    uuid: "{{ vm_initial_info.instance.hw_product_uuid }}"
    validate_certs: no
  register: snapshot_info
  delegate_to: localhost

- name: スナップショットが存在する場合はすべて削除（統合）する
  community.vmware.vmware_guest_snapshot:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    datacenter: "{{ vmware_datacenter }}"
    uuid: "{{ vm_initial_info.instance.hw_product_uuid }}"
    validate_certs: no
    state: remove_all
  delegate_to: localhost
  when: snapshot_info.guest_snapshots.current_snapshot is defined

- name: VMDKパス特定のために最新情報を再取得
  community.vmware.vmware_guest_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    name: "{{ inventory_hostname }}"
    validate_certs: no
  register: vm_final_info 
  delegate_to: localhost

# -------------------------------------------------------
# 2. ディスクパスの特定
# -------------------------------------------------------
- name: vmdkファイルのパスを抽出してリスト化
  ansible.builtin.set_fact:
    vmdk_paths: >-
      {{
        vm_final_info.instance.hw_files
        | select('search', '\.vmdk$')
        | reject('search', '-[0-9]{6}\.vmdk$')
        | list
      }}

- name: "ディスクの情報を構造化し、移行先ストレージを動的判定"
  ansible.builtin.set_fact:
    disk_info_list: >-
      {%- set results = [] -%}
      {%- for path in vmdk_paths -%}
        {%- set ds_name = (path | regex_replace('^\\[(.*?)\\] .*$', '\\1')) -%}
        {%- set relative_path = (path | regex_replace('^\\[.*?\\] (.*)$', '\\1')) -%}
        {%- set abs_path = '/vmfs/volumes/' ~ ds_name ~ '/' ~ relative_path -%}

        {# ▼判定条件: VMwareのデータストア名に 'nas' が含まれているか（小文字区別なし） #}
        {%- set is_nas = ('nas' in ds_name | lower) -%}

        {# ▼移行先ストレージと、アタッチ時のボリュームパスを決定 #}
        {%- if is_nas -%}
          {%- set t_store = proxmox_storage -%}
          {%- set t_vol = t_store ~ ':' ~ vmid ~ '/vm-' ~ vmid ~ '-disk-' ~ loop.index0 ~ '.raw' -%}
        {%- else -%}
          {%- set t_store = 'local-lvm' -%}
          {%- set t_vol = t_store ~ ':vm-' ~ vmid ~ '-disk-' ~ loop.index0 -%}
        {%- endif -%}

        {%- set _ = results.append({
          'datastore': ds_name,
          'absolute_path': abs_path,
          'basename': relative_path | basename,
          'target_storage': t_store,
          'target_volume': t_vol
        }) -%}
      {%- endfor -%}
      {{ results }}

- name: "DEBUG: 判定されたディスク情報を出力"
  ansible.builtin.debug:
    var: disk_info_list

root@pve01:/etc/ansible/roles/legacyos_migration/tasks# cat import_disk.yml
---
- name: vmdkファイルの格納用ディレクトリ作成
  file:
    path: "/mnt/pve/{{ proxmox_storage }}/tmp/v2vtmp-{{ vm_name }}"
    state: directory
    mode: '0755'
  delegate_to: localhost
  when: not ansible_check_mode

- name: "ESXiからvmdkファイルを転送 (SCP)"
  ansible.builtin.command:
    cmd: >-
      sshpass -p "{{ esxi_root_password }}"
      scp
      -o StrictHostKeyChecking=no
      -o HostKeyAlgorithms=+ssh-rsa
      -o PubkeyAcceptedAlgorithms=+ssh-rsa
      root@{{ vm_final_info.instance.hw_esxi_host }}:"{{ item.absolute_path | regex_replace('\.vmdk$', '*.vmdk') }}"
      /mnt/pve/{{ proxmox_storage }}/tmp/v2vtmp-{{ vm_name }}/
  delegate_to: localhost
  loop: "{{ disk_info_list }}"
  loop_control:
    label: "{{ item.basename }}"
  when: not ansible_check_mode

- name: "対象VMのVMDKディスクを検索"
  ansible.builtin.find:
    paths: /mnt/pve/{{ proxmox_storage }}/tmp/v2vtmp-{{ vm_name }}/
    patterns: "^{{ inventory_hostname }}(_\\d+)?.vmdk$"
    use_regex: true
  register: vmdk_files
  delegate_to: "{{ node_name }}"
  when: not ansible_check_mode 

- name: "Proxmoxへディスクをインポート"
  ansible.builtin.command:
    cmd: >-
      qm importdisk {{ vmid }}
      /mnt/pve/{{ proxmox_storage }}/tmp/v2vtmp-{{ vm_name }}/{{ item.basename }}
      {{ item.target_storage }} --format raw
  delegate_to: "{{ node_name }}"
  loop: "{{ disk_info_list }}"
  loop_control:
    label: "Importing to {{ item.target_storage }}"
  register: import_results
  changed_when: true
  when: not ansible_check_mode

- name: "インポートしたディスクをIDEデバイスとしてアタッチ (CentOS 4用)"
  ansible.builtin.command:
    cmd: "qm set {{ vmid }} --ide{{ idx }} {{ item.target_volume }}"
  delegate_to: "{{ node_name }}"
  loop: "{{ disk_info_list }}"
  loop_control:
    index_var: idx
    label: "Attaching {{ item.target_volume }} to ide{{ idx }}"
  changed_when: true
  when:
    - os_major_version | default('') | string == '4'
    - not ansible_check_mode

- name: "インポートしたディスクをVirtIO Blockとしてアタッチ (CentOS 5用)"
  ansible.builtin.command:
    cmd: "qm set {{ vmid }} --virtio{{ idx }} {{ item.target_volume }},discard=on"
  delegate_to: "{{ node_name }}"
  loop: "{{ disk_info_list }}"
  loop_control:
    index_var: idx
  changed_when: true
  when:
    - os_major_version | default('') | string == '5'
    - not ansible_check_mode

- name: "インポートしたディスクをSCSIデバイスとしてアタッチ (CentOS 6用)"
  ansible.builtin.command:
    cmd: "qm set {{ vmid }} --scsi{{ idx }} {{ item.target_volume }},discard=on"
  delegate_to: "{{ node_name }}"
  loop: "{{ disk_info_list }}"
  loop_control:
    index_var: idx
    label: "Attaching {{ item.target_volume }} to scsi{{ idx }}"
  changed_when: true
  when:
    - os_major_version | default('') | string == '6'
    - not ansible_check_mode

- name: "ブート順をインポートしたシステムディスクに設定"
  ansible.builtin.command:
    cmd: >-
      qm set {{ vmid }} --boot order={% if os_major_version | default('') | string == '4' %}ide0{% elif os_major_version | default('') | string == '5' %}virtio0{% else %}scsi0{% endif %}
  delegate_to: "{{ node_name }}"
  changed_when: true
  when: not ansible_check_mode

- name: "一時ディレクトリの削除"
  ansible.builtin.file:
    path: "/mnt/pve/{{ proxmox_storage }}/tmp/v2vtmp-{{ vm_name }}"
    state: absent
  delegate_to: localhost
  when: not ansible_check_mode

- name: "ディスク処理完了メッセージ"
  ansible.builtin.debug:
    msg: "VM {{ vmid }} ({{ inventory_hostname }}) へのディスクアタッチが正常に完了しました。"
  when: not ansible_check_mode
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# cat main.yml
---
- name: 対象VMのNIC情報を収集
  ansible.builtin.include_tasks: collect_nic.yml
  tags: [ collect_nic ]

- name: 空のVMを作成(CentOS5用)
  ansible.builtin.include_tasks: vmcreate.yml
  tags: [ vmcreate ]

- name: 各VMの停止 + 移行処理
  ansible.builtin.include_tasks: exec_migration.yml
  tags: [ exec_migration ]

- name: vmdkファイルの転送・インポート・アタッチ処理を実行"
  ansible.builtin.include_tasks: import_disk.yml
  tags: [ import_disk ]
root@pve01:/etc/ansible/roles/legacyos_migration/tasks# cat vmcreate.yml 
- name: NIC情報をファイルから直接読み込み、変数辞書に登録
  ansible.builtin.set_fact:
    proxmox_net_config: |
      {% set current_nic_info = lookup('file', '/tmp/' + inventory_hostname + '_nic_data.json') | from_json %}
      {% set nic_dict = {} %}
      {% for nic in current_nic_info.nics_to_configure %}
        {# ▼ CentOS 4 は e1000、CentOS 5以上 は高速な virtio を指定 #}
        {% set nic_model = 'e1000' if os_major_version | default('') | string == '4' else 'virtio' %}
        {% set nic_params = [
              nic_model,
              'bridge=' ~ proxmox_bridge,
              'macaddr=' ~ nic.mac
            ]
        %}
        {% if nic.vlan_id is defined and nic.vlan_id | int > 0 %}
          {% set _ = nic_params.append('tag=' ~ nic.vlan_id) %}
        {% endif %}
        {% set _ = nic_dict.update({'net' ~ loop.index0: nic_params | join(',')}) %}
      {% endfor %}
      {{ nic_dict | to_yaml }}
  when: not ansible_check_mode

- name: "DEBUG: 登録した内容を表示"
  debug:
    msg:
      - "inventory_hostname={{ inventory_hostname }}"
      - "vmid(var)={{ vmid | default('UNDEF') }}"
      - "hostvars[...] vmid={{ hostvars[inventory_hostname].vmid | default('UNDEF') }}"

- name: "vCenterからVMのスペック情報を取得"
  community.vmware.vmware_guest_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    validate_certs: no
    name: "{{ inventory_hostname }}"
  register: vm_source_info
  delegate_to: localhost
  when: not ansible_check_mode

- name: "Proxmox上にVMを作成"
  community.general.proxmox_kvm:
    # Proxmox API 接続情報
    api_host: "{{ hostvars[node_name].proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_password: "{{ proxmox_api_password }}"
    validate_certs: no

    # VMの基本設定
    node: "{{ node_name }}"
    name: "{{ hostvars[inventory_hostname].vm_name }}"
    memory: "{{ vm_source_info.instance.hw_memtotal_mb }}"
    cores: "{{ vm_source_info.instance.hw_processor_count }}"
    cpu: kvm64
    # ▼ CentOS 4 と 5 は古いチップセット(pc/i440fx)を使用、それ以外は q35
    machine: "{% if os_major_version | default('') | string in ['4', '5'] %}pc{% else %}q35{% endif %}"
    scsihw: lsi
    onboot: 1
    vmid: "{{ hostvars[inventory_hostname].vmid }}"
    ostype: l26
    state: present
    net: "{{ proxmox_net_config | from_yaml }}"
  environment:
    http_proxy: ""
    https_proxy: ""
    HTTP_PROXY: ""
    HTTPS_PROXY: ""
  register: proxmox_vm_create_result
  delegate_to: localhost
  when: not ansible_check_mode

- name: "DEBUG - Proxmox VM作成の結果を確認"
  ansible.builtin.debug:
    var: proxmox_vm_create_result
  when: proxmox_vm_create_result is defined



root@pve01:/etc/ansible/roles/mount# ls
tasks
root@pve01:/etc/ansible/roles/mount# cd tasks/
root@pve01:/etc/ansible/roles/mount/tasks# ls
main.yml
root@pve01:/etc/ansible/roles/mount/tasks# cat main.yml 
---
- name: "インポート対象のディスクイメージを検索"
  ansible.builtin.find:
    paths: "/mnt/pve/nas-vmstore/tmp/v2vtmp-{{ vm_name }}"
    patterns:
      - "{{ vm_name }}-*"
      - "{{ vm_name | replace('-', '_') }}-*"
    file_type: file
  register: found_disk_files
  delegate_to: "{{ node_name }}"
  when: not ansible_check_mode

- name: "ディスクイメージのインポート"
  ansible.builtin.command:
    cmd: "qm importdisk {{ vmid }} {{ item.path }} {{ target_storages[idx] | default('local-lvm') }} --format=raw"
  loop: "{{ found_disk_files.files | default([]) | sort(attribute='path') }}"
  loop_control:
    index_var: idx
  register: import_results
  delegate_to: "{{ node_name }}"
  retries: 3         # 最大3回まで再試行
  delay: 30          # 再試行する前に30秒待機（ロックが解けるのを待つ）
  until: import_results.rc == 0  # 成功(rc=0)するまで繰り返す
  when: not ansible_check_mode

- name: "DEBUG: インポート結果の確認"
  ansible.builtin.debug:
    msg:
      - "Cmd: {{ item.cmd | default('') }}"
      - "Stdout: {{ item.stdout | default('') }}"
      - "Stderr: {{ item.stderr | default('') }}"
  loop: "{{ import_results.results | default([]) }}"
  loop_control:
    label: "Result for {{ item.item.path | default('Skipped') }}"
  delegate_to: localhost
  when: not ansible_check_mode

- name: "インポートしたディスクをSCSIとしてアタッチ"
  ansible.builtin.command:
    cmd: >-
      qm set {{ vmid }}
      --scsi{{ index }} {{ (item.stdout | default('') ~ item.stderr | default('')) | regex_search("(?i)successfully imported disk '([^']+)'", '\1') | first | default('') }},discard=on,iothread=on,ssd=1
  loop: "{{ import_results.results | default([]) }}"
  loop_control:
    index_var: index
    label: "Attach disk {{ index }} from import result"
  delegate_to: "{{ node_name }}"
  when:
    - not ansible_check_mode
    - (item.stdout | default('') ~ item.stderr | default('')) is search("(?i)successfully imported disk")
  changed_when: true

- name: "ブート順を最初のディスク(scsi0)に設定"
  ansible.builtin.command:
    cmd: "qm set {{ vmid }} --boot order=scsi0"
  changed_when: true
  delegate_to: "{{ node_name }}"
  when: not ansible_check_mode

- name: "インポート用の一時ディレクトリを削除"
  ansible.builtin.file:
    path: "/mnt/pve/nas-vmstore/tmp/v2vtmp-{{ vm_name }}"
    state: absent
  delegate_to: "{{ node_name }}"
  when: not ansible_check_mode
  
  
  
root@pve01:/etc/ansible/roles/poweron_vm/tasks# ls
main.yml
root@pve01:/etc/ansible/roles/poweron_vm/tasks# 
root@pve01:/etc/ansible/roles/poweron_vm/tasks# 
root@pve01:/etc/ansible/roles/poweron_vm/tasks# cat main.yml 
# ----------------------------------------
# VMの起動と状態確認
# ----------------------------------------
- name: "移行したVMの起動"
  ansible.builtin.command:
    cmd: "qm start {{ vmid }}"
  delegate_to: "{{ node_name }}"
  changed_when: true

- name: "VMのOS起動（SSH接続）を待機 (最大5分)"
  ansible.builtin.wait_for:
    host: "{{ ansible_host }}"
    port: 22
    state: started
    timeout: 300  # 300秒(5分)経っても繋がらなければタイムアウト
  delegate_to: localhost
  register: boot_result
  ignore_errors: true  # 失敗しても一旦処理を継続させ、次のタスクで判定する

- name: "起動状態の判定とエラー出力"
  ansible.builtin.fail:
    msg: >-
      [エラー] VM ({{ inventory_hostname }}) の起動確認に失敗しました。
      カーネルパニックやネットワーク設定の不整合によりOSが正常に立ち上がっていない可能性があります。
      ProxmoxのGUIコンソール画面からVMの状態を確認してください。
  when: boot_result.failed

- name: "正常起動のメッセージ"
  ansible.builtin.debug:
    msg: "VM ({{ inventory_hostname }}) の正常起動（SSH応答）を確認しました。"
  when:
    - not boot_result.failed
    - not ansible_check_mode
    
    
    
root@pve01:/etc/ansible/roles# cd shutdown_vm/
root@pve01:/etc/ansible/roles/shutdown_vm# ls
tasks
root@pve01:/etc/ansible/roles/shutdown_vm# cd tasks/
root@pve01:/etc/ansible/roles/shutdown_vm/tasks# ls
main.yml
root@pve01:/etc/ansible/roles/shutdown_vm/tasks# cat main.yml 
- name: VMの電源状態を確認
  community.vmware.vmware_guest_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    validate_certs: no
    name: "{{ inventory_hostname }}"
  register: vm_shutdown_info
  delegate_to: localhost

- name: "対象VMの停止 (VMwareTools稼働時はゲストシャットダウン)"
  community.vmware.vmware_guest:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    name: "{{ inventory_hostname }}"
    state: shutdown-guest
    validate_certs: no
  delegate_to: localhost
  when: 
    - vm_shutdown_info.instance.hw_power_status == 'poweredOn'
    - vm_shutdown_info.instance.guest_tools_status == 'guestToolsRunning'

- name: "対象VMの停止 (VMwareTools非実行時はSSH経由でシャットダウン)"
  ansible.builtin.command: "shutdown -h now"
  ignore_unreachable: true
  ignore_errors: true
  delegate_to: "{{ inventory_hostname }}"
  when:
    - vm_shutdown_info.instance.hw_power_status == 'poweredOn'
    - vm_shutdown_info.instance.guest_tools_status != 'guestToolsRunning'

- name: "対象VMが完全に停止するまで待機"
  community.vmware.vmware_guest_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    name: "{{ inventory_hostname }}"
    validate_certs: no
  register: vm_info
  # vm_info.instance.power_stateが'poweredOff'になるまで繰り返す
  until: "vm_info.instance.hw_power_status == 'poweredOff'"
  retries: 30      # 最大30回試行
  delay: 10        # 10秒ごとに確認
  delegate_to: localhost
  when: not ansible_check_mode
  


root@pve01:/etc/ansible/roles/vmcreate# cd tasks/
root@pve01:/etc/ansible/roles/vmcreate/tasks# ls
main.yml
root@pve01:/etc/ansible/roles/vmcreate/tasks# 
root@pve01:/etc/ansible/roles/vmcreate/tasks# 
root@pve01:/etc/ansible/roles/vmcreate/tasks# 
root@pve01:/etc/ansible/roles/vmcreate/tasks# 
root@pve01:/etc/ansible/roles/vmcreate/tasks# 
root@pve01:/etc/ansible/roles/vmcreate/tasks# 
root@pve01:/etc/ansible/roles/vmcreate/tasks# 
root@pve01:/etc/ansible/roles/vmcreate/tasks# cat main.yml 
---
- name: NIC情報をファイルから直接読み込み、変数辞書に登録
  ansible.builtin.set_fact:
    proxmox_net_config: |
      {% set current_nic_info = lookup('file', '/tmp/' + inventory_hostname + '_nic_data.json') | from_json %}
      {% set nic_dict = {} %}
      {% for nic in current_nic_info.nics_to_configure %}
        {% set nic_params = [
              'virtio',
              'bridge=' ~ proxmox_bridge,
              'macaddr=' ~ nic.mac
            ]
        %}
        {% if nic.vlan_id is defined and nic.vlan_id | int > 0 %}
          {% set _ = nic_params.append('tag=' ~ nic.vlan_id) %}
        {% endif %}
        {% set _ = nic_dict.update({'net' ~ loop.index0: nic_params | join(',')}) %}
      {% endfor %}
      {{ nic_dict | to_yaml }}
  when: not ansible_check_mode

- name: "DEBUG: 登録した内容を表示"
  debug:
    msg:
      - "inventory_hostname={{ inventory_hostname }}"
      - "vmid(var)={{ vmid | default('UNDEF') }}"
      - "hostvars[...] vmid={{ hostvars[inventory_hostname].vmid | default('UNDEF') }}"

- name: "vCenterからVMのスペック情報を取得"
  community.vmware.vmware_guest_info:
    hostname: "{{ vcenter_host }}"
    username: "{{ vcenter_user }}"
    password: "{{ vcenter_password }}"
    validate_certs: no
    name: "{{ inventory_hostname }}"
  register: vm_source_info
  delegate_to: localhost
  when: not ansible_check_mode

- name: "Proxmox上にVMを作成"
  community.general.proxmox_kvm:
    # Proxmox API 接続情報
    api_host: "{{ hostvars[node_name].proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_password: "{{ proxmox_api_password }}"
    validate_certs: no

    # VMの基本設定
    node: "{{ hostvars[inventory_hostname].node_name }}"
    name: "{{ hostvars[inventory_hostname].vm_name }}"
    memory: "{{ vm_source_info.instance.hw_memtotal_mb }}"
    cores: "{{ vm_source_info.instance.hw_processor_count }}"
    cpu: x86-64-v2-AES
    machine: q35
    scsihw: virtio-scsi-single
    agent: 1
    onboot: 1
    vmid: "{{ hostvars[inventory_hostname].vmid }}"
    ostype: l26
    state: present
    net: "{{ proxmox_net_config | from_yaml }}"
  environment:
    http_proxy: ""
    https_proxy: ""
    HTTP_PROXY: ""
    HTTPS_PROXY: ""
  register: proxmox_vm_create_result
  delegate_to: localhost
  when: not ansible_check_mode

- name: "DEBUG - Proxmox VM作成の結果を確認"
  ansible.builtin.debug:
    var: proxmox_vm_create_result
  when: proxmox_vm_create_result is defined