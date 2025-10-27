pipeline {
    agent any

    tools {
        maven 'Maven3'   // Ensure 'Maven3' is configured in Jenkins global tools
        jdk 'Java17'     // Ensure 'Java17' is configured in Jenkins global tools
    }

    environment {
        // CORRECTION: Append /repository/${NEXUS_REPO}/ to the base URL for deployment
        NEXUS_BASE_URL = "http://13.222.23.48:30881"
        NEXUS_REPO     = "maven-releases"
        NEXUS_DEPLOY_URL = "${NEXUS_BASE_URL}/repository/${NEXUS_REPO}/" // Fixed deployment URL
        
        SONAR_HOST_URL = "http://18.206.252.221" // Removed trailing slash for consistency
        AWS_REGION     = "us-east-1"
        AWS_ACCOUNT_ID = "615299740590"
        ECR_REPO       = "demo-sonar-repo"
        WORKSPACE_DIR  = "${env.WORKSPACE}"
    }

    triggers {
        githubPush()
    }

    stages {
        
        stage('Prepare Workspace') {
            steps {
                echo "Fixing permissions..."
                // Removed redundant chown/chmod if Jenkins runs as the correct user,
                // but kept the original for environment compatibility if needed.
                sh 'sudo chown -R jenkins:jenkins $WORKSPACE_DIR || true'
                sh 'sudo chmod -R 755 $WORKSPACE_DIR || true'
            }
        }

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Code Scan (SonarQube)') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            mvn -B clean verify sonar:sonar \
                                -Dsonar.host.url=${SONAR_HOST_URL} \
                                -Dsonar.login=${SONAR_TOKEN}
                        '''
                    }
                }
            }
        }

        stage('Build Application') {
            steps {
                // Better practice: Use -DskipTests=true for 'package' if running tests in a separate 'test' stage.
                // Since you skip them during deploy, let's keep the setting for 'package' consistent.
                sh 'mvn -B clean package -DskipTests=true' 
            }
        }

        stage('Store Artifacts in Nexus') {
    steps {
        withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
            sh '''
                mvn -B deploy -DskipTests \
                -DaltDeploymentRepository=nexus::default::$NEXUS_DEPLOY_URL \
                -Dnexus.username=$NEXUS_USER \
                -Dnexus.password=$NEXUS_PASS
            '''
        }
    }
}


        stage('Docker Build & Push to AWS ECR') {
            steps {
                script {
                    def ecrUri = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
                    withAWS(credentials: 'aws-ecr-creds', region: "${AWS_REGION}") {
                        sh """
                            # 1. Create ECR repo if it doesn't exist
                            aws ecr describe-repositories --repository-names ${ECR_REPO} || \
                                aws ecr create-repository --repository-name ${ECR_REPO}

                            # 2. Login to ECR
                            aws ecr get-login-password | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                            # 3. Build and Push with GIT_COMMIT tag
                            docker build -t ${ECR_REPO}:${GIT_COMMIT} .
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:${GIT_COMMIT}
                            docker push ${ecrUri}:${GIT_COMMIT}

                            # 4. Tag and Push with 'latest'
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:latest
                            docker push ${ecrUri}:latest
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completed successfully."
        }
        failure {
            echo "❌ Pipeline failed. Check logs for details."
        }
    }
}
