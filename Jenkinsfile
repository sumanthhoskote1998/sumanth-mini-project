pipeline {
    agent any

    tools {
        maven 'Maven3'       // Make sure Maven3 is configured under Jenkins Global Tools
        jdk 'Java17'         // Ensure Java17 is configured
    }

    environment {
        // Nexus
        NEXUS_BASE_URL   = "http://13.222.23.48:30881"
        NEXUS_REPO       = "maven-releases"
        NEXUS_DEPLOY_URL = "${NEXUS_BASE_URL}/repository/${NEXUS_REPO}/"

        // SonarQube
        SONAR_HOST_URL   = "http://18.206.252.221"

        // AWS / ECR
        AWS_REGION       = "us-east-1"
        AWS_ACCOUNT_ID   = "615299740590"
        ECR_REPO         = "demo-sonar-repo"

        // Jenkins workspace
        WORKSPACE_DIR    = "${env.WORKSPACE}"
    }

    triggers {
        githubPush()  // Automatically trigger build on GitHub push
    }

    stages {

        stage('Prepare Workspace') {
            steps {
                echo "🔧 Fixing permissions for workspace..."
                sh 'sudo chown -R jenkins:jenkins $WORKSPACE_DIR || true'
                sh 'sudo chmod -R 755 $WORKSPACE_DIR || true'
            }
        }

        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/sumanthhoskote1998/sumanth-mini-project.git'
            }
        }

        stage('Code Scan - SonarQube') {
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
                sh 'mvn -B clean package -DskipTests=true'
            }
        }

        stage('Upload Artifact to Nexus') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-credentials',
                                                  usernameVariable: 'NEXUS_USER',
                                                  passwordVariable: 'NEXUS_PASS')]) {
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
                            echo "🔐 Logging in to AWS ECR..."
                            aws ecr describe-repositories --repository-names ${ECR_REPO} || \
                                aws ecr create-repository --repository-name ${ECR_REPO} --region ${AWS_REGION}

                            aws ecr get-login-password --region ${AWS_REGION} | \
                                docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                            echo "🐳 Building Docker image..."
                            docker build -t ${ECR_REPO}:${GIT_COMMIT} .

                            echo "🏷️ Tagging Docker image..."
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:${GIT_COMMIT}
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:latest

                            echo "📤 Pushing Docker image to ECR..."
                            docker push ${ecrUri}:${GIT_COMMIT}
                            docker push ${ecrUri}:latest
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completed successfully! Images pushed to ECR."
        }
        failure {
            echo "❌ Pipeline failed. Check the console output for details."
        }
    }
}
