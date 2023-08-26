#! /bin/bash
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
sudo chmod a+rwx /opt/aws/amazon-cloudwatch-agent/etc/
cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "append_dimensions": {
            "InstanceId": "${aws:InstanceId}"
        },
        "metrics_collected": {

            "disk": {
                "measurement": [{
                    "name": "disk_used_percent",
                    "rename": "DiskUtilization"
                }
                ],
                "metrics_collection_interval": 60,
                "resources": [
                  "/"
                ]
              },
            "mem": {
                "measurement": [{
                        "name": "mem_used_percent",
                        "rename": "MemoryUtilization"
                    },
                    {
                        "name": "mem_available",
                        "rename": "MemoryAvailable"
                    }
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "/"
                ]
            }

        }
    }
}
EOT
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start