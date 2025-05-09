// @Library('slack') _

pipeline {
  agent any

  environment {
    deploymentName = "devsecops"
    containerName = "devsecops-container"
    serviceName = "devsecops-svc"
    imageName = "orszaghlev/numeric-app:v1"
    applicationURL="http://devsecops-orszaghlev.eastus.cloudapp.azure.com"
    applicationURI="/increment/99"
  }

  stages {
      stage('Build Artifact') {
            steps {
              sh "mvn clean package -DskipTests=true"
              archive 'target/*.jar'
            }
        }   
      stage('Unit Tests') {
            steps {
              sh "mvn test"
            }
        } 
      stage('Mutation Tests') {
            steps {
              sh "mvn org.pitest:pitest-maven:mutationCoverage"
            }
        } 
      stage('Static Analysis') {
          steps {
            withSonarQubeEnv('sonarqube') {
              sh "mvn clean verify sonar:sonar -Dsonar.projectKey=numeric-application -Dsonar.projectName='numeric-application'"
            }
            timeout(time: 2, unit: 'MINUTES') {
              script {
                waitForQualityGate abortPipeline: true
              }
            }
          }
        }   
      stage('Vulnerability Scan - Docker') {
          steps {
            parallel(
              "Dependency Scan": {
                sh "mvn dependency-check:check"
              },
              "Trivy Scan": {
                sh "bash trivy-docker-image-scan.sh"
              },
              "OPA Conftest": {
                sh 'docker run --rm -v $(pwd):/project openpolicyagent/conftest test --policy opa-docker-security.rego Dockerfile'
              }
            )
          }
        }
      stage('Build and Push') {
            steps {
              withDockerRegistry([credentialsId: "docker-hub", url: ""]) {
                sh "printenv"
                sh "sudo docker build -t orszaghlev/numeric-app:v1 ."
                sh "docker push orszaghlev/numeric-app:v1"
              }
            }
        }
      stage('Vulnerability Scan - Kubernetes') {
          steps {
            parallel (
              "OPA Scan": {
                sh 'docker run --rm -v $(pwd):/project openpolicyagent/conftest test --policy opa-k8s-security.rego k8s_deployment_service.yaml'
              },
              "Kubesec Scan": {
                sh "bash kubesec-scan.sh"
              },
              "Trivy Scan": {
                sh "bash trivy-k8s-scan.sh"
              }
            )
          }
        }
      stage('Dev Deployment') {
            steps {
              parallel(
                "Deployment": {
                  withKubeConfig([credentialsId: "kubeconfig"]) {
                    sh "bash k8s-deployment.sh"
                  }
                },
                "Rollout": {
                  withKubeConfig([credentialsId: "kubeconfig"]) {
                    sh "bash k8s-deployment-rollout-status.sh"
                  }
                }
              )
            }
        }  
      stage('Integration Tests') {
            steps {
              script {
                try {
                  withKubeConfig([credentialsId: "kubeconfig"]) {
                    sh "bash integration-test.sh"
                  }
                } catch (e) {
                  withKubeConfig([credentialsId: "kubeconfig"]) {
                    sh "kubectl -n default rollout undo deploy ${deploymentName}"
                  }
                  throw e
                }
              }
            }
      }
      stage('ZAP Report') {
            steps {
              withKubeConfig([credentialsId: "kubeconfig"]) {
                sh "bash zap.sh"
              }
            }
        }
      stage('Promote to PROD?') {
            steps {
              timeout(time: 2, unit: 'DAYS') {
                input "Do you want to approve the deployment to production environment?"
              }
            }
        }
      stage('CIS Benchmark') {
        steps {
              script {
                parallel(
                  "Master": {
                    sh "bash cis-master.sh"
                  },
                  "etcd": {
                    sh "bash cis-etcd.sh"
                  },
                  "Kubelet": {
                    sh "bash cis-kubelet.sh"
                  }
                )
                }
              }
        }
      stage('Prod Deployment') {
            steps {
              parallel(
                "Deployment": {
                  withKubeConfig([credentialsId: "kubeconfig"]) {
                    sh "kubectl -n prod apply -f k8s_PROD_deployment_service.yaml"
                  }
                },
                "Rollout": {
                  withKubeConfig([credentialsId: "kubeconfig"]) {
                    sh "bash k8s-PROD-deployment-rollout-status.sh"
                  }
                }
              )
            }
        }  
      stage('Prod Integration Tests') {
            steps {
              script {
                try {
                  withKubeConfig([credentialsId: "kubeconfig"]) {
                    sh "bash integration-test-prod.sh"
                  }
                } catch (e) {
                  withKubeConfig([credentialsId: "kubeconfig"]) {
                    sh "kubectl -n prod rollout undo deploy ${deploymentName}"
                  }
                  throw e
                }
              }
            }
      }
      stage('Testing Slack') {
        steps {
          sh 'exit 0'
        }
      }
    }

    post {
      always {
        junit 'target/surefire-reports/*.xml'
        jacoco execPattern: 'target/jacoco.exec'
        pitmutation mutationStatsFile: '**/target/pit-reports/**/mutations.xml'
        dependencyCheckPublisher pattern: 'target/dependency-check-report.xml'
        publishHTML([allowMissing: false, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: 'owasp-zap-report', reportFiles: 'zap_report.html', reportName: 'HTML Report', reportTitles: 'OWASP ZAP Report', useWrapperFileDirectly: true])
        // sendNotification currentBuild.result
      }
    }
}