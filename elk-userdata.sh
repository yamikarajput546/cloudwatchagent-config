#!/bin/bash
sudo apt update && sudo apt install awscli -y
sudo chmod a+rwx /etc/systemd/system
sudo chmod a+rwx /usr/local/src
cat <<EOT > /usr/local/src/script.sh
#!/bin/bash
while true; do      
        if [ -z $(curl -v http://169.254.169.254/latest/meta-data/spot/instance-action | head -1 | grep 404 | cut -d ' ' -f 2) ]; then
            echo "404(healthy instance)"
        else
            curl -X POST -H 'Content-Type: application/json' 'https://chat.googleapis.com/v1/spaces/AAAAQpron5M/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=iZv8RZW7O3hAexBOk5ZxTyOhtEK-Th9Dun3HobRuyYk%3D' -d '{"text": "'"Spot Instance not healthy , invoking the lambda "'"}' && aws lambda invoke --function-name "elk-production-lambda-function" --log-type Tail ./lambda_log.txt --region "ap-south-1"
            sleep 300
        fi
done
EOT
cat <<EOT > /etc/systemd/system/spot.service
[Unit]
Description=spot service

[Service]
ExecStart=/usr/local/src/script.sh

[Install]
WantedBy=multi-user.target
EOT

sudo chmod 777 /usr/local/src/script.sh 
sudo systemctl start spot

service ufw stop
aws ec2 associate-address --instance-id `wget -q -O - http://169.254.169.254/latest/meta-data/instance-id` --allocation-id "eipalloc-04a99693b58667f06" --allow-reassociation --region "ap-south-1"

export id_apm=$(aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:ap-south-1:068875301997:targetgroup/kibana-apm/eb73b3c6b200208e  --query 'TargetHealthDescriptions[*].Target.Id' --output text --region "ap-south-1")

export id_kibana=$(aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:ap-south-1:068875301997:targetgroup/kibana-http/b68d901ed8338d3e  --query 'TargetHealthDescriptions[*].Target.Id' --output text --region "ap-south-1")


aws elbv2 deregister-targets --target-group-arn arn:aws:elasticloadbalancing:ap-south-1:068875301997:targetgroup/kibana-http/b68d901ed8338d3e --targets Id=$id_kibana --region "ap-south-1"


aws elbv2 deregister-targets --target-group-arn arn:aws:elasticloadbalancing:ap-south-1:068875301997:targetgroup/kibana-apm/eb73b3c6b200208e --targets Id=$id_apm --region "ap-south-1"

aws elbv2 register-targets --target-group-arn arn:aws:elasticloadbalancing:ap-south-1:068875301997:targetgroup/kibana-http/b68d901ed8338d3e --targets Id=`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`,Port=80 --region "ap-south-1"
aws elbv2 register-targets --target-group-arn arn:aws:elasticloadbalancing:ap-south-1:068875301997:targetgroup/kibana-apm/eb73b3c6b200208e --targets Id=`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`,Port=8200 --region "ap-south-1"

wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo rm /var/lib/dpkg/lock
sudo rm /var/lib/dpkg/lock-frontend
sudo dpkg --configure -a
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:AmazonCloudWatch-asg
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start