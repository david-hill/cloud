#!/bin/bash

yum install -y jenkins
systemctl enable jenkins
systemctl start jenkins

cat<<EOF>/etc/suoders.d/jenkins
Defaults visiblepw
jenkins	ALL=(ALL) 	NOPASSWD:ALL
EOF
