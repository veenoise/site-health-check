#!/usr/bin/env bash

SITE_URL=$1
SLACK_WEBHOOK_URL=$2

# Ensure proper script dir
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check arguments
if [[ -z "$SITE_URL" || -z "$SLACK_WEBHOOK_URL" ]]; then
    echo "Usage: $0 <site_url> <slack_webhook_url>"
    exit 1
fi

# Check if .metadata.txt exists
if [[ ! -f $DIR/.metadata.txt ]]; then
    echo -e "SITE_STATUS=UP\nSTORAGE_STATUS=OK" > $DIR/.metadata.txt
fi

# Get site status
CURL_RES=$(curl -s -L -o /dev/null -w "%{http_code}" -m 5 "$SITE_URL")

# Get current metadata SITE_STATUS
SITE_STATUS=$(cat $DIR/.metadata.txt | grep SITE_STATUS= | sed s/SITE_STATUS=//)

# Check if site is down
if [[ 
        $CURL_RES -ne 200 && 
        "$SITE_STATUS" == "UP" 
    ]]; then
    curl -X POST $SLACK_WEBHOOK_URL \
    -H 'Content-type: application/json' \
    --data '
    {
        "attachments": [
            {
                "color": "danger",
                "title": "⚠️ Site Down",
                "text": "The application is currently unreachable or returned an error status. Please investigate immediately.",
                "fields": [
                    {
                        "title": "Status",
                        "value": "DOWN",
                        "short": true
                    },
                    {
                        "title": "Environment",
                        "value": "Production",
                        "short": true
                    }
                ],
                "footer": "Monitoring Bot",
                "ts": '$(date +%s)'
            }
        ]
    }'

    sed -i.bak 's/SITE_STATUS=UP/SITE_STATUS=DOWN/' $DIR/.metadata.txt

# Check if site is up
elif [[   
        $CURL_RES -eq 200 && 
        "$SITE_STATUS" == "DOWN"
    ]]; then
    curl -X POST $SLACK_WEBHOOK_URL \
    -H 'Content-type: application/json' \
    --data '
    {
        "attachments": [
            {
                "color": "good",
                "title": "✅ Site Up",
                "text": "The application is up and running.",
                "fields": [
                    {
                        "title": "Status",
                        "value": "UP",
                        "short": true
                    },
                    {
                        "title": "Environment",
                        "value": "Production",
                        "short": true
                    }
                ],
                "footer": "Monitoring Bot",
                "ts": '$(date +%s)'
            }
        ]
    }'

    sed -i.bak 's/SITE_STATUS=DOWN/SITE_STATUS=UP/' $DIR/.metadata.txt
fi

# Get storage usage
DISK_USAGE=$(df -h | grep /$ | awk '{print $5}' | sed s/%//)

# Get current metadata STORAGE_STATUS
STORAGE_STATUS=$(cat $DIR/.metadata.txt | grep STORAGE_STATUS= | sed s/STORAGE_STATUS=//)

# Check if disk is full (95% disk usage alert)
if [[ 
        $DISK_USAGE -ge 95 &&
        $STORAGE_STATUS == "OK"
    ]]; then 
    curl -X POST $SLACK_WEBHOOK_URL \
    -H 'Content-type: application/json' \
    --data '
    {
        "attachments": [
            {
                "color": "danger",
                "title": "⚠️ Server disk usage >= 95%",
                "text": "The server disk space is running low. Please investigate immediately.",
                "fields": [
                    {
                        "title": "Status",
                        "value": "DISK ALMOST FULL",
                        "short": true
                    },
                    {
                        "title": "Environment",
                        "value": "Production",
                        "short": true
                    }
                ],
                "footer": "Monitoring Bot",
                "ts": '$(date +%s)'
            }
        ]
    }'

    sed -i.bak 's/STORAGE_STATUS=OK/STORAGE_STATUS=WARN/' $DIR/.metadata.txt

# Check if disk issue was resolved (95% disk usage alert)
elif [[ 
        $DISK_USAGE -lt 95 &&
        $STORAGE_STATUS == "WARN"
    ]]; then 
    curl -X POST $SLACK_WEBHOOK_URL \
    -H 'Content-type: application/json' \
    --data '
    {
        "attachments": [
            {
                "color": "good",
                "title": "✅ Server disk usage < 95%",
                "text": "The server disk space is OK.",
                "fields": [
                    {
                        "title": "Status",
                        "value": "DISK OK",
                        "short": true
                    },
                    {
                        "title": "Environment",
                        "value": "Production",
                        "short": true
                    }
                ],
                "footer": "Monitoring Bot",
                "ts": '$(date +%s)'
            }
        ]
    }'

    sed -i.bak 's/STORAGE_STATUS=WARN/STORAGE_STATUS=OK/' $DIR/.metadata.txt
fi