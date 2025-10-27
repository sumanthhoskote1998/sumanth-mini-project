pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        REPO_NAME = "demo-sonar-repo"
        IMAGE_TAG = "${BUILD_NUMBER}"
        ECR_URL = "615299740590.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/sumanthhoskote1998/demo-sonar-nexus-ecr.git'
            }
        }

        stage('Build with Maven') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('SonarQube Analysis') {
            environment {
                scannerHome = tool 'sonar-scanner'
            }
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh '''
                        ${scannerHome}/bin/sonar-scanner \
                        -Dsonar.projectKey=demo-sonar-nexus-ecr \
                        -Dsonar.sources=src \
                        -Dsonar.java.binaries=target/classes
                    '''
                }
            }
        }

        stage('Docker Build & Push to AWS ECR') {
            steps {
                script {
                    withAWS(region: "${AWS_REGION}", credentials: 'aws-credentials') {
                        sh '''
                            echo "Ensuring ECR repository exists..."
                            aws ecr describe-repositories --repository-names ${REPO_NAME} || \
                            aws ecr create-repository --repository-name ${REPO_NAME}

                            echo "Logging in to ECR..."
                            aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_URL}

                            echo "Building Docker image..."
                            docker build -t ${REPO_NAME}:${IMAGE_TAG} .

                            echo "Tagging Docker image..."
                            docker tag ${REPO_NAME}:${IMAGE_TAG} ${ECR_URL}:${IMAGE_TAG}

                            echo "Pushing Docker image to ECR..."
                            docker push ${ECR_URL}:${IMAGE_TAG}
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed. Please check above logs for the error details."
        }
    }
}
