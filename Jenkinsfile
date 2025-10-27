pipeline {
    agent any

    environment {
        NEXUS_REPO_URL = 'http://13.222.23.48:30881/repository/maven-releases/'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git 'https://github.com/your-repo/demo-sonar-nexus-ecr.git'
            }
        }

        stage('Build Artifact') {
            steps {
                sh 'mvn clean package -DskipTests=true'
            }
        }

        stage('Upload Artifact to Nexus') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    sh '''
                        echo "Uploading artifact to Nexus..."
                        curl -v -u ${NEXUS_USER}:${NEXUS_PASS} \
                          --upload-file target/demo-sonar-nexus-ecr-0.1.0.jar \
                          ${NEXUS_REPO_URL}com/example/demo-sonar-nexus-ecr/0.1.0/demo-sonar-nexus-ecr-0.1.0.jar
                    '''
                }
            }
        }

        stage('Docker Build & Push to AWS ECR') {
            steps {
                echo 'Docker and ECR steps go here...'
                // Add your ECR build and push steps here
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline executed successfully!"
        }
        failure {
            echo "❌ Pipeline failed. Check logs for error details."
        }
    }
}
