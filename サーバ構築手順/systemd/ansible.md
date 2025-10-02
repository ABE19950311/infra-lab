■ 前提条件
・OS
[root@c22383d8a0fb /]# cat /etc/redhat-release
AlmaLinux release 8.10 (Cerulean Leopard)
・epel-releaseインストール済み
・ミドルウェアインストール時にインターネットへの経路が存在していること
・ansibleバージョンは2.3.0.0


■ 作業手順

1. ansibleユーザ作成
※group,uidはかぶらないもので任意
``````````````````````````````````````
# groupadd -g 731 ansible
# useradd ansible -g 731 -m -u 731
``````````````````````````````````````

2. sudoersに追加
``````````````````````````````````````
# chmod 640 /etc/sudoers
# vi /etc/sudoers
----------------以下を追記-------------
# Add ansible user
ansible ALL=(ALL) NOPASSWD: ALL

``````````````````````````````````````

3. ansibleユーザに切り替え
``````````````````````````````````````
# su - ansible
``````````````````````````````````````

4. pip,python-devel,gcc,sshpassインストール
``````````````````````````````````````
//pip
$ curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
$ python3 get-pip.py --user
// python-devel,gcc,sshpass
$ sudo dnf install -y python3-devel gcc sshpass
``````````````````````````````````````

5. ansibleインストール
``````````````````````````````````````
$ pip install --user ansible\==2.3.0.0
$ ansible --version
``````````````````````````````````````

6. 各ディレクトリ、ファイル作成
``````````````````````````````````````
$ mkdir -p /home/ansible/ansible
$ mkdir -p /home/ansible/ansible/inventories/common
$ mkdir -p /home/ansible/ansible/inventories/dev/group_vars
$ mkdir -p /home/ansible/ansible/roles
$ touch /home/ansible/ansible/inventories/dev/hosts
$ touch /home/ansible/ansible/ansible.cfg
$ touch /home/ansible/ansible/www.yml
$ touch /home/ansible/ansible/ap.yml
$ touch /home/ansible/ansible/db.yml
$ touch /home/ansible/ansible/mail.yml
$ touch /home/ansible/ansible/nfs.yml
$ touch /home/ansible/ansible/all.yml
$ cd /home/ansible/ansible/roles
$ ansible-galaxy init common
$ ansible-galaxy init base-alma
$ ansible-galaxy init apache
$ ansible-galaxy init nfsmount
$ ansible-galaxy init nfsserver
$ mkdir /home/ansible/ansible/roles/apache/files
※/home/ansible/ansible/roles/apache/filesに適用するssl証明書、秘密鍵を設置する
※証明書のuser,groupはansibleユーザに変えておく
$ mkdir /home/ansible/ansible/roles/apache/templates
※/home/ansible/ansible/roles/apache/filesにhttpd.confを拡張子j2で設置する
``````````````````````````````````````

7. 共通内容追記
``````````````````````````````````````
$ vi /home/ansible/ansible/ansible.cfg
[defaults]
#hostfile = hosts
remote_user = ansible
become = true
host_key_checking = false

$ vi /home/ansible/ansible/inventories/dev/hosts
※以下ホスト内容で/etc/hostsも追記する
------------以下を追記-----------------
[www]
web1

[ap]
ap1

[db]
db1

[other]
nfs

$ vi /home/ansible/ansible/roles/common/handlers/main.yml
---
- name: httpd 再起動
  systemd:
    name: httpd
    daemon_reload: yes
    state: restarted

$ vi /home/ansible/ansible/roles/base-alma/tasks/main.yml
---
#- { include: network.yml,        tags: base.network        }
#- { include: chrony.yml,         tags: base.chrony         }
- { include: syslog.yml,         tags: base.syslog         }
#- { include: selinux.yml,        tags: base.selinux        }
- { include: add_packages.yml,   tags: base.add_packages   }
#- { include: snmp.yml,           tags: base.snmp           }
#- { include: nrpe.yml,           tags: base.nrpe           }
- { include: firewalld.yml,      tags: base.firewalld      }
#- { include: syslog_rotate.yml,  tags: base.syslog_rotate  }

$ vi /home/ansible/ansible/roles/base-alma/tasks/syslog.yml
---
- name: syslog / rsyslog パッケージ導入
  dnf:
    name: "{{ item }}"
    state: present
  with_items:
    - rsyslog

- name: syslog / rsyslog起動
  systemd:
    name: '{{ item }}'
    enabled: yes
    state: started
  with_items:
    - rsyslog

$ vi /home/ansible/ansible/roles/base-alma/tasks/selinux.yml
---
- name: selinux / ansible selinux モジュール 必須パッケージ導入
  dnf:
    name: '{{ item }}'
    state: present
  with_items:
    - python3-libselinux
- name: selinux / selinux 無効
  selinux:
    state: disabled

$ vi /home/ansible/ansible/roles/base-alma/tasks/add_packages.yml
---
- name: add_packages / 追加パッケージインストール
  dnf:
    name: '{{ item }}'
    state: present
  with_items:
    - bind-utils
    - wget
    - mailx
    - sysstat
    - procps
    - unzip
    - whois
    - zip
    - lsof
    - iotop
    - procps-ng

$ vi /home/ansible/ansible/roles/base-alma/tasks/firewalld.yml
---
- name: Try to install firewalld
  dnf:
    name: '{{ item }}'
    state: present
  with_items:
    - firewalld

- name: firewall停止
  service:
    name: firewalld
    state: stopped
    enabled: no

$ vi /home/ansible/ansible/all.yml
# ここではroleのincludeのみ行うこと(taskを書かない)
---
- include: www.yml
- include: ap.yml
- include: db.yml
- include: mail.yml


8. www設定追記

$ vi /home/ansible/ansible/www.yml
------------以下を追記-----------------
---
- hosts: www
  become: true
  #vars_files:
    #- inventories/common/var.yml
    #- inventories/common/secret.yml
    #- inventories/dev/var.yml
  environment:
    http_proxy: "{{ http_proxy | default('') }}"
  roles:
    - common
    - base-alma
    - nfsmount
    #- script-perl
    #- script-php
    #- application-settings
    - apache
    #- aws-cli

$ vi /home/ansible/ansible/roles/apache/tasks/main.yml
---
- { include: httpd.yml,             tags: apache.www.httpd             }

$ vi /home/ansible/ansible/roles/apache/tasks/httpd.yml
---
- name: httpd mod_ssl openssl 導入
  dnf:
    name: '{{ item }}'
    state: present
  with_items:
    - httpd
    - mod_ssl
    - openssl

- name: httpd / httpd.conf ファイル設置
  template:
    src: ../templates/httpd.conf.www.j2
    dest: /etc/httpd/conf/httpd.conf
    owner: root
    group: root
    mode: 0600
  tags:
    httpd.conf
  notify: httpd 再起動

- name: httpd / certs ディレクトリ作成
  file:
    path: /etc/httpd/conf.d/certs
    owner: root
    group: root
    mode: 0755
    state: directory
  tags:
    httpd.conf

- name: httpd / certs ファイル設置
  copy:
    src:  '{{ item.src  }}'
    dest: '{{ item.dest }}'
    owner: root
    group: root
    mode: 0400
  with_items:
    - { src: '../files/server.crt', dest: '/etc/httpd/conf.d/certs/server.crt' }
    - { src: '../files/server.key', dest: '/etc/httpd/conf.d/certs/server.key' }
  tags:
    httpd.conf
  notify: httpd 再起動

- name: httpd / httpd 起動
  systemd:
    name: '{{ item }}'
    enabled: yes
    state: started
  with_items:
    - httpd

$ vi /home/ansible/ansible/inventories/dev/group_vars/www.yml
hoge: 
  nfs:
    mount:
      - { host: 172.28.10.15, path: /srv/nfs, mount_dir: /mnt/nfs, opts: 'vers=3,proto=tcp,hard,intr,bg' }

``````````````````````````````````````

9. ap設定追記
``````````````````````````````````````



``````````````````````````````````````


10. nfsサーバ設定追記
``````````````````````````````````````
$ vi /home/ansible/ansible/nfs.yml
------------以下を追記-----------------
---
- hosts: other
  become: true
  #vars_files:
    #- inventories/common/var.yml
    #- inventories/common/secret.yml
    #- inventories/dev/var.yml
  environment:
    http_proxy: "{{ http_proxy | default('') }}"
  roles:
    - nfsserver

$ vi /home/ansible/ansible/roles/nfsserver/tasks/main.yml
---
- { include: nfsserver.yml, tags: nfsserver }


$ vi /home/ansible/ansible/roles/nfsserver/tasks/nfsserver.yml
---
- name: nfs_mount / nfs 必須パッケージ導入
  dnf:
    name: '{{ item }}'
    state: present
  with_items:
    - nfs-utils
    - e2fsprogs

- name: nfs 起動
  systemd:
    name: '{{ item }}'
    enabled: yes
    state: started
  with_items:
    - nfs-server

- name: Create disk image file (1GB)
  command: 
    cmd: 'dd if=/dev/zero of=/srv/nfs_disk.img bs=1M count=1024'
  #creates: /srv/nfs_disk.img errorになる

- name: Create ext4 filesystem
  command: 
    cmd: 'mkfs.ext4 /srv/nfs_disk.img'
 
- name: Create mount point
  file:
    path: /srv/nfs
    state: directory
    mode: '0755'

- name: Mount the disk image to /srv/nfs
  mount:
    path: /srv/nfs
    src: /srv/nfs_disk.img
    fstype: ext4
    opts: loop
    state: mounted

- name: Ensure /etc/exports entry exists
  lineinfile:
    path: /etc/exports
    line: "/srv/nfs 172.28.0.0/16(rw,async,no_root_squash)"
    create: yes

- name: Export NFS shares
  command: 
    cmd: 'exportfs -rv'
``````````````````````````````````````

11 nfsクライアント設定追記
``````````````````````````````````````
$ vi /home/ansible/ansible/roles/nfsmount/tasks/main.yml
---
- { include: nfsmount.yml, tags: nfsmount }

$ vi /home/ansible/ansible/roles/nfsmount/tasks/nfsmount.yml
---
- name: nfs_mount / nfs 必須パッケージ導入
  dnf:
    name: '{{ item }}'
    state: present
  with_items:
    - nfs-utils

- name: nfs_mount / nfsマウントディレクトリ作成
  file:
    path:  '{{ item.path  }}'
    owner: '{{ item.owner }}'
    group: '{{ item.group }}'
    mode:  '{{ item.mode  }}'
    state: directory
  with_items:
   - { path: /mnt/nfs, owner: root, group: root, mode: '0755' }

- name: nfs_mount / nfsマウント
  mount:
    name: '{{ item.mount_dir }}'
    src:  '{{ item.host }}:{{ item.path }}'
    opts: '{{ item.opts }}'
    fstype: nfs
    state: mounted
  with_items:
    '{{ hoge.nfs.mount }}'

``````````````````````````````````````












00. dryrunとrun
``````````````````````````````````````
$ ansible-playbook www.yml -i inventories/dev/hosts -l www --ask-pass --diff -e 'ansible_python_interpreter=/usr/bin/python3' -C
⇒failedが出ないことを確認
$ ansible-playbook www.yml -i inventories/dev/hosts -l www --ask-pass --diff -e 'ansible_python_interpreter=/usr/bin/python3'
``````````````````````````````````````