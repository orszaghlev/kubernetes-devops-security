pipeline {
  agent any

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
      stage('Vulnerability Scan') {
            parallel {
                stage('Dependency Check') {
                    steps {
                        sh 'mvn dependency-check:check'
                    }
                }
                stage('Trivy') {
                    steps {
                        sh 'bash trivy-docker-image-scan.sh'
                    }
                }
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
      stage('Dev Deployment') {
            steps {
              withKubeConfig([credentialsId: "kubeconfig"]) {
                sh "kubectl apply -f k8s_deployment_service.yaml"
              }
            }
        }  
    }

    post {
      always {
        junit 'target/surefire-reports/*.xml'
        jacoco execPattern: 'target/jacoco.exec'
        pitmutation mutationStatsFile: '**/target/pit-reports/**/mutations.xml'
        dependencyCheckPublisher pattern: 'target/dependency-check-report.xml'
      }
    }
}