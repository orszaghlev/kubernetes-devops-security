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
            post {
              always {
                junit 'target/surefire-reports/*.xml'
                jacoco execPattern: 'target/jacoco.exec'
              }
            }
        } 
      stage('Build and Push') {
            steps {
              withDockerRegistry([credentialsId: "docker-hub", url: ""]) {
                sh "printenv"
                sh "docker build -t orszaghlev/numeric-app:v1"
                sh "docker push orszaghlev/numeric-app:v1"
              }
            }
        }
      stage('Dev Deployment') {
            steps {
              withKubeConfig([credentialsId: "kubeconfig"]) {
                sh "sed -i 's#replace#orszaghlev/numeric-app:v1#g' k8s_deployment_service.yaml"
                sh "kubectl apply -f k8s_deployment_service.yaml"
              }
            }
        }  
    }
}