■ Install AWS CLI
```
$ curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
$ unzip awscliv2.zip
$ sudo ./aws/install
```

■ Install terraform by tfenv
```
$ git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
$ echo 'export PATH=$PATH:$HOME/.tfenv/bin' >> ~/.bashrc
$ source ~/.bashrc
$ tfenv install
$ tfenv use
```

■ Check versions
```
$ aws --version
$ tfenv --version
$ terraform --version
```

■ Configure AWS CLI
```
$ aws configure --profile terraform
```