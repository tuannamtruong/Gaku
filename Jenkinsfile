pipeline {
    agent any

    triggers {
        pollSCM('H/2 * * * *')
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        CI_IMAGE      = "gaku-ci:${env.BUILD_NUMBER}"
        CONTAINER     = "gaku-ci-${env.BUILD_NUMBER}"
        TEST_RESULTS  = "TestResults"
    }

    stages {

        stage('Restore & Build') {
            steps {
                dir('/home/nam/Gaku') {
                    sh """
                        docker build \\
                            --target build \\
                            --tag ${env.CI_IMAGE} \\
                            --file docker/Dockerfile.ci \\
                            .
                    """
                }
            }
        }

        stage('Test — Domain') {
            steps {
                dir('/home/nam/Gaku') {
                    sh """
                        docker run --name ${env.CONTAINER}-domain \\
                            --entrypoint dotnet \\
                            ${env.CI_IMAGE} \\
                            test tests/Gaku.Domain.Tests/Gaku.Domain.Tests.csproj \\
                                -c Release --no-build \\
                                --logger "junit;LogFilePath=/TestResults/domain/junit.xml" \\
                                --results-directory /TestResults/domain
                    """
                }
            }
            post {
                always {
                    sh """
                        mkdir -p ${env.TEST_RESULTS}/domain
                        docker cp ${env.CONTAINER}-domain:/TestResults/domain/junit.xml \\
                            ${env.TEST_RESULTS}/domain/junit.xml || true
                        docker rm -f ${env.CONTAINER}-domain || true
                    """
                    junit allowEmptyResults: true,
                          testResults: "${env.TEST_RESULTS}/domain/junit.xml"
                }
            }
        }

        stage('Test — Application') {
            steps {
                dir('/home/nam/Gaku') {
                    sh """
                        docker run --name ${env.CONTAINER}-application \\
                            --entrypoint dotnet \\
                            ${env.CI_IMAGE} \\
                            test tests/Gaku.Application.Tests/Gaku.Application.Tests.csproj \\
                                -c Release --no-build \\
                                --logger "junit;LogFilePath=/TestResults/application/junit.xml" \\
                                --results-directory /TestResults/application
                    """
                }
            }
            post {
                always {
                    sh """
                        mkdir -p ${env.TEST_RESULTS}/application
                        docker cp ${env.CONTAINER}-application:/TestResults/application/junit.xml \\
                            ${env.TEST_RESULTS}/application/junit.xml || true
                        docker rm -f ${env.CONTAINER}-application || true
                    """
                    junit allowEmptyResults: true,
                          testResults: "${env.TEST_RESULTS}/application/junit.xml"
                }
            }
        }

        stage('Test — Infrastructure') {
            steps {
                dir('/home/nam/Gaku') {
                    sh """
                        docker run --name ${env.CONTAINER}-infrastructure \\
                            --entrypoint dotnet \\
                            ${env.CI_IMAGE} \\
                            test tests/Gaku.Infrastructure.Tests/Gaku.Infrastructure.Tests.csproj \\
                                -c Release --no-build \\
                                --logger "junit;LogFilePath=/TestResults/infrastructure/junit.xml" \\
                                --results-directory /TestResults/infrastructure
                    """
                }
            }
            post {
                always {
                    sh """
                        mkdir -p ${env.TEST_RESULTS}/infrastructure
                        docker cp ${env.CONTAINER}-infrastructure:/TestResults/infrastructure/junit.xml \\
                            ${env.TEST_RESULTS}/infrastructure/junit.xml || true
                        docker rm -f ${env.CONTAINER}-infrastructure || true
                    """
                    junit allowEmptyResults: true,
                          testResults: "${env.TEST_RESULTS}/infrastructure/junit.xml"
                }
            }
        }
    }

    post {
        always {
            sh "docker rmi --no-prune ${env.CI_IMAGE} || true"
        }
        success {
            echo 'All layers built and tested successfully.'
        }
        failure {
            echo 'Build or tests failed. Check the Test Results tab for details.'
        }
    }
}
