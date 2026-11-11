#!/bin/sh
# Updates or rollback Jenkins's plugins, then restart Jenkins.
#
#   sh jenkins-plugins.sh update|rollback local|ec2
#
set -u

ACTION=${1:-}
PLATFORM=${2:-}

case "$PLATFORM" in
    local)
        JENKINS_HOME=/var/jenkins_home
        JENKINS_URL=http://localhost:8090
        ROLLBACK_TARGET=jenkins_plugins_rollback

        # Start a separate process in the Jenkins container to avoid logging in to Jenkins.
        jenkins_exec() { docker exec gaku-jenkins "$@"; }
        plugin_cli() { jenkins_exec jenkins-plugin-cli "$@"; }
        restart_jenkins() { docker restart gaku-jenkins >/dev/null; }
        jenkins_log() {
            docker logs --since "$(docker inspect -f '{{.State.StartedAt}}' gaku-jenkins)" gaku-jenkins 2>&1
        }
        ;;
    ec2)
        JENKINS_HOME=/var/lib/jenkins
        JENKINS_URL=http://localhost:8080
        ROLLBACK_TARGET=jenkins_aws_plugins_rollback

        # The RPM install has no jenkins-plugin-cli. This is the version the local image ships.
        PLUGIN_MANAGER_VERSION=2.15.0
        PLUGIN_MANAGER_JAR=/opt/jenkins-plugin-manager-$PLUGIN_MANAGER_VERSION.jar
        PLUGIN_MANAGER_URL=https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/$PLUGIN_MANAGER_VERSION/jenkins-plugin-manager-$PLUGIN_MANAGER_VERSION.jar

        # Start a separate process as the jenkins user, so the files it writes stay owned by Jenkins.
        jenkins_exec() { runuser -u jenkins -- "$@"; }
        plugin_cli() {
            if [ ! -f "$PLUGIN_MANAGER_JAR" ]; then
                curl -fsSLo "$PLUGIN_MANAGER_JAR.part" "$PLUGIN_MANAGER_URL" \
                    && mv "$PLUGIN_MANAGER_JAR.part" "$PLUGIN_MANAGER_JAR" \
                    || return 1
            fi
            jenkins_exec java -jar "$PLUGIN_MANAGER_JAR" --war /usr/share/java/jenkins.war "$@"
        }
        restart_jenkins() { systemctl restart jenkins; }
        jenkins_log() {
            journalctl --no-pager _SYSTEMD_INVOCATION_ID="$(systemctl show -p InvocationID --value jenkins)"
        }
        ;;
    *)
        echo "Usage: $0 update|rollback local|ec2"
        exit 1
        ;;
esac

# Restart so Jenkins loads the plugins on disk and wait up to 2 minutes for the login page.
# Fails when Jenkins does not answer, or when this run's log shows a plugin that did not load.
restart_and_check() {
    restart_jenkins || return 1
    for i in $(seq 40); do
        if [ "$(curl -s -o /dev/null -w '%{http_code}' "$JENKINS_URL/login")" = 200 ]; then
            break
        fi
        sleep 3
    done
    if [ "$(curl -s -o /dev/null -w '%{http_code}' "$JENKINS_URL/login")" != 200 ]; then
        echo "Jenkins did not answer on $JENKINS_URL/login within 2 minutes"
        return 1
    fi
    if jenkins_log | grep -E 'SEVERE|Failed Loading'; then
        return 1
    fi
}

update() {
    # 1. Stop if Jenkins cannot be reached or a build is running. A running Pipeline has completed==false in its build.xml.
    if ! jenkins_exec true; then
        echo "[FAIL] Cannot run commands next to Jenkins - is it running?"
        exit 1
    fi
    if jenkins_exec grep -rqs --include=build.xml '<completed>false</completed>' "$JENKINS_HOME/jobs"; then
        echo "[FAIL] A build is running - retry when it finishes"
        exit 1
    fi

    # 2. List the installed plugins as name:version and print the outdated ones. Nothing outdated: exit.
    PLUGINS=$(plugin_cli -d "$JENKINS_HOME/plugins" --list 2>&1 \
        | awk '/^Installed plugins:/{in_list=1;next} /^$/{in_list=0} in_list{print $1":"$2}')
    if [ -z "$PLUGINS" ]; then
        echo "[FAIL] Could not list the installed plugins"
        exit 1
    fi
    if ! UPDATE_REPORT=$(plugin_cli -d /tmp/pc --no-download --available-updates --plugins $PLUGINS 2>&1); then
        echo "$UPDATE_REPORT"
        echo "[FAIL] Could not check for updates"
        exit 1
    fi
    if ! echo "$UPDATE_REPORT" | grep 'has an available update'; then
        echo "[OK] All plugins are up to date"
        exit 0
    fi

    # 3. Back up the current plugins, replacing the previous backup, for the rollback target.
    if ! jenkins_exec sh -c "cd $JENKINS_HOME && rm -rf plugins.bak && cp -a plugins plugins.bak"; then
        echo "[FAIL] Backup failed - nothing was changed"
        exit 1
    fi

    # 4. Download the latest version of every plugin that supports this Jenkins core into jenkins_home.
    #    Jenkins keeps running the old plugins until it restarts, so a failure here does not take it down.
    if ! plugin_cli -d "$JENKINS_HOME/plugins" --plugins $(echo "$PLUGINS" | sed 's/:.*/:latest/') >/dev/null; then
        echo "[FAIL] Download failed - run make $ROLLBACK_TARGET before the next restart"
        exit 1
    fi

    # 5. Restart and check that every plugin loaded.
    if ! restart_and_check; then
        echo "[FAIL] Errors above - make $ROLLBACK_TARGET restores the previous plugins"
        exit 1
    fi
    echo "[OK] Plugins updated and Jenkins is up"
}

rollback() {
    if ! jenkins_exec sh -c "cd $JENKINS_HOME && test -d plugins.bak && rm -rf plugins && mv plugins.bak plugins"; then
        echo "[FAIL] No plugins.bak to restore"
        exit 1
    fi
    if ! restart_and_check; then
        echo "[FAIL] Errors above after restoring plugins.bak"
        exit 1
    fi
    echo "[OK] Previous plugins restored and Jenkins is up"
}

case "$ACTION" in
    update) update ;;
    rollback) rollback ;;
    *)
        echo "Usage: $0 update|rollback local|ec2"
        exit 1
        ;;
esac
