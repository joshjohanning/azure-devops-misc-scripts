#!/bin/bash
agentuser=${AGENT_USER}
pool=${AGENT_POOL}
pat=${AGENT_TOKEN}
azdourl=${AZDO_URL}
# other install stuff here...
# azdo agent
mkdir -p /opt/azdo && cd /opt/azdo
cd /opt/azdo
curl -o azdoagent.tar.gz https://vstsagentpackage.azureedge.net/agent/2.175.2/vsts-agent-linux-x64-2.175.2.tar.gz
tar xzvf azdoagent.tar.gz
rm -f azdoagent.tar.gz
# configure as azdouser
chown -R $agentuser /opt/azdo
chmod -R 755 /opt/azdo
runuser -l $agentuser -c "/opt/azdo/config.sh --unattended --url $azdourl --auth pat --token $pat --pool $pool --acceptTeeEula"
# install and start the service
./svc.sh install
./svc.sh start