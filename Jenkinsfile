pipeline {
    agent any

    triggers {
        githubPush()
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
        API_IMAGE     = "gaku-api"
        WEB_IMAGE     = "gaku-web"
        IMAGE_TAG     = "${env.BUILD_NUMBER}"
    }

    stages {

        stage('Environment Info') {
            steps {
                sh """
                    echo "WORKSPACE   = ${env.WORKSPACE}"
                    echo "BUILD_NUMBER = ${env.BUILD_NUMBER}"
                    uname -a
                    docker version --format 'Docker {{.Server.Version}}'
                    dotnet --version || true
                """
            }
        }

        stage('Restore & Build') {
            steps {
                sh """
                    docker build \\
                        --target build \\
                        --tag ${env.CI_IMAGE} \\
                        --file docker/Dockerfile.ci \\
                        .
                """
            }
        }

        stage('Test — Domain') {
            steps {
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

        stage('Test — Web') {
            steps {
                sh """
                    docker run --name ${env.CONTAINER}-web \\
                        --entrypoint dotnet \\
                        ${env.CI_IMAGE} \\
                        test tests/Gaku.Web.Tests/Gaku.Web.Tests.csproj \\
                            -c Release --no-build \\
                            --logger "junit;LogFilePath=/TestResults/web/junit.xml" \\
                            --results-directory /TestResults/web
                """
            }
            post {
                always {
                    sh """
                        mkdir -p ${env.TEST_RESULTS}/web
                        docker cp ${env.CONTAINER}-web:/TestResults/web/junit.xml \\
                            ${env.TEST_RESULTS}/web/junit.xml || true
                        docker rm -f ${env.CONTAINER}-web || true
                    """
                    junit allowEmptyResults: true,
                          testResults: "${env.TEST_RESULTS}/web/junit.xml"
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -f docker/Dockerfile.Gaku.Api -t ${env.API_IMAGE}:${env.IMAGE_TAG} -t ${env.API_IMAGE}:latest ."
                sh "docker build -f docker/Dockerfile.Gaku.Web -t ${env.WEB_IMAGE}:${env.IMAGE_TAG} -t ${env.WEB_IMAGE}:latest ."
            }
        }

        stage('Load Images into Minikube') {
            when { branch 'master' }
            steps {
                sh "minikube image load ${env.API_IMAGE}:${env.IMAGE_TAG}"
                sh "minikube image load ${env.API_IMAGE}:latest"
                sh "minikube image load ${env.WEB_IMAGE}:${env.IMAGE_TAG}"
                sh "minikube image load ${env.WEB_IMAGE}:latest"
            }
        }

        stage('Deploy to Local K8s') {
            when { branch 'master' }
            steps {
                sh "kubectl set image deployment/gaku-api gaku-api=${env.API_IMAGE}:${env.IMAGE_TAG} -n gaku"
                sh "kubectl set image deployment/gaku-web gaku-web=${env.WEB_IMAGE}:${env.IMAGE_TAG} -n gaku"
                sh "kubectl rollout status deployment/gaku-api -n gaku --timeout=120s"
                sh "kubectl rollout status deployment/gaku-web -n gaku --timeout=120s"
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
