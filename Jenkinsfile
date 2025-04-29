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
      stage('Mutation Tests') {
            steps {
              sh "mvn org.pitest:pitest-maven:mutationCoverage"
            }
            post {
              always {
                pitmutation mutationStatsFile: '**/target/pit-reports/**/mutations.xml'
              }
            }
        } 
      stage('SonarQube Analysis') {
          steps {
            withSonarQubeEnv('sonarqube') {
              sh "mvn clean verify sonar:sonar -Dsonar.projectKey=numeric-application -Dsonar.projectName='numeric-application' -Dsonar.token='sqp_5086713149f0009fdf132d511526d222bd9edbc8'"
            }
            timeout(time: 2, unit: 'MINUTES') {
              script {
                waitForQualityGate abortPipeline: true
              }
            }
          }
        }   
      stage('Build and Push') {
            steps {
              withDockerRegistry([credentialsId: "docker-hub", url: ""]) {
                sh "printenv"
                sh "docker build -t orszaghlev/numeric-app:v1 ."
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
}