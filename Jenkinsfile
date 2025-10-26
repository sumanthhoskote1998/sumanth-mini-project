cat > Jenkinsfile <<'EOF'
pipeline {
  agent any

  environment {
    NEXUS_URL       = "http://<NEXUS_HOST>:8081"
    NEXUS_REPO      = "maven-releases"
    NEXUS_CREDS     = credentials('nexus-credentials')    // username/password credential id
    SONAR_HOST_URL  = "http://<SONAR_HOST>:9000"
    SONAR_TOKEN     = credentials('sonar-token')         // secret text
    AWS_REGION      = "us-east-1"
    AWS_ACCOUNT_ID  = "<AWS_ACCOUNT_ID>"
    ECR_REPO        = "demo-sonar-repo"
    AWS_CREDENTIALS = credentials('aws-creds')
  }

  triggers {
    githubPush()
  }

  stages {
    stage('Checkout Code') {
      steps {
        checkout scm
      }
    }

    stage('Code Scan (SonarQube)') {
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          sh '''
            mvn -B clean verify sonar:sonar \
              -Dsonar.host.url=${SONAR_HOST_URL} \
              -Dsonar.login=${SONAR_TOKEN}
          '''
        }
      }
    }

    stage('Build') {
      steps {
        sh 'mvn -B -DskipTests=false package'
      }
    }

    stage('Store Artifacts in Nexus') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
          sh '''
            mvn -B deploy -DskipTests \
              -DaltDeploymentRepository=nexus::default::${NEXUS_URL}/repository/${NEXUS_REPO}/ \
              -Dnexus.username=${NEXUS_USER} -Dnexus.password=${NEXUS_PASS}
          '''
        }
      }
    }

    stage('Docker Image Build & Push to AWS ECR') {
      steps {
        script {
          def ecrUri = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
          withCredentials([[
              $class: 'AmazonWebServicesCredentialsBinding',
              credentialsId: 'aws-creds'
            ]]) {
            sh '''
              aws ecr describe-repositories --region ${AWS_REGION} --repository-names ${ECR_REPO} || \
                aws ecr create-repository --region ${AWS_REGION} --repository-name ${ECR_REPO}

              aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

              docker build -t ${ECR_REPO}:${GIT_COMMIT} .
              docker tag ${ECR_REPO}:${GIT_COMMIT} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${GIT_COMMIT}
              docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${GIT_COMMIT}

              docker tag ${ECR_REPO}:${GIT_COMMIT} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest
              docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest
            '''
          }
        }
      }
    }
  }

  post {
    success {
      echo "Pipeline completed successfully."
    }
    failure {
      echo "Pipeline failed."
    }
  }
}
EOF

