#!/bin/bash
# Datadog Agent install script for Mac OS X.
set -e
logfile=ddagent-install.log
gist_request=/tmp/agent-gist-request.tmp
gist_response=/tmp/agent-gist-response.tmp
dmg_file=/tmp/datadog-agent.dmg
dmg_url="http://dd-pastebin.s3.amazonaws.com/dd-agent/datadog-agent-5.3.0.dmg"

# Root user detection
if [ $(echo "$UID") = "0" ]; then
    sudo_cmd=''
else
    sudo_cmd='sudo'
fi

# get real user (in case of sudo)
real_user=`logname`
export TMPDIR=`sudo -u $real_user getconf DARWIN_USER_TEMP_DIR`
cmd_real_user="sudo -Eu $real_user"

# In order to install with the right user
rm -f /tmp/datadog-install-user
echo $real_user > /tmp/datadog-install-user

function on_error() {
    printf "\033[31m$ERROR_MESSAGE
It looks like you hit an issue when trying to install the Agent.

Troubleshooting and basic usage information for the Agent are available at:

    http://docs.datadoghq.com/guides/basic_agent_usage/

If you're still having problems, please send an email to support@datadoghq.com
with the contents of ddagent-install.log and we'll do our very best to help you
solve your problem.\n\033[0m\n"
}
trap on_error ERR

if [ -n "$DD_API_KEY" ]; then
    apikey=$DD_API_KEY
fi

if [ ! $apikey ]; then
    printf "\033[31mAPI key not available in DD_API_KEY environment variable.\033[0m\n"
    exit 1;
fi

# Install the agent
printf "\033[34m\n* Downloading and installing datadog-agent\n\033[0m"
$sudo_cmd rm -f $dmg_file
curl $dmg_url > $dmg_file
$sudo_cmd hdiutil detach "/Volumes/datadog_agent" >/dev/null 2>&1 || true
$sudo_cmd hdiutil attach "$dmg_file" -mountpoint "/Volumes/datadog_agent" >/dev/null
cd / && $sudo_cmd /usr/sbin/installer -pkg `find "/Volumes/datadog_agent" -name \*.pkg 2>/dev/null` -target / >/dev/null
$sudo_cmd hdiutil detach "/Volumes/datadog_agent" >/dev/null

# Set the configuration
if egrep 'api_key:( APIKEY)?$' "/Applications/Datadog Agent.app/Contents/Resources/datadog.conf" > /dev/null 2>&1; then
    printf "\033[34m\n* Adding your API key to the Agent configuration: datadog.conf\n\033[0m\n"
    $sudo_cmd sh -c "sed -i '' 's/api_key:.*/api_key: $apikey/' \"/Applications/Datadog Agent.app/Contents/Resources/datadog.conf\""
    $sudo_cmd chown $real_user:admin "/Applications/Datadog Agent.app/Contents/Resources/datadog.conf"
    printf "\033[34m* Restarting the Agent...\n\033[0m\n"
    $cmd_real_user "/Applications/Datadog Agent.app/Contents/MacOS/datadog-agent" restart >/dev/null
else
    printf "\033[34m\n* Keeping old datadog.conf configuration file\n\033[0m\n"
fi

# Wait for metrics to be submitted by the forwarder
printf "\033[32m
Your Agent has started up for the first time. We're currently verifying that
data is being submitted. You should see your Agent show up in Datadog shortly
at:

    https://app.datadoghq.com/infrastructure\033[0m

Waiting for metrics..."

c=0
while [ "$c" -lt "30" ]; do
    sleep 1
    echo -n "."
    c=$(($c+1))
done

curl -f http://127.0.0.1:17123/status?threshold=0 > /dev/null 2>&1
success=$?
while [ "$success" -gt "0" ]; do
    sleep 1
    echo -n "."
    curl -f http://127.0.0.1:17123/status?threshold=0 > /dev/null 2>&1
    success=$?
done

# Metrics are submitted, echo some instructions and exit
printf "\033[32m

Your Agent is running and functioning properly. It will continue to run in the
background and submit metrics to Datadog.

If you ever want to stop the Agent, please use the Datadog Agent App.

If you want to enable it at startup, run these commands: (the agent will still run as your user)

    sudo cp '/Applications/Datadog Agent.app/Contents/Resources/com.datadoghq.Agent.plist' /Library/LaunchDaemons
    sudo launchctl load -w /Library/LaunchDaemons/com.datadoghq.Agent.plist

\033[0m"