// Runs at every controller start to register jenkins agent to the controller.
import hudson.slaves.DumbSlave
import hudson.slaves.JNLPLauncher
import jenkins.model.Jenkins

def jenkins = Jenkins.get()
if (jenkins.getNode('agent') == null) {
    def agent = new DumbSlave('agent', '/home/jenkins/agent', new JNLPLauncher())
    agent.numExecutors = 2
    jenkins.addNode(agent)
}
new File('/run/jenkins-agent/secret').text = jenkins.getComputer('agent').jnlpMac
