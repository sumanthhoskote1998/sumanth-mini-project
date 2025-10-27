pipeline {
    agent any

    tools {
        maven 'Maven3'    // Ensure configured under Manage Jenkins → Global Tool Configuration
        jdk 'Java17'      // Ensure configured under Manage Jenkins → Global Tool Configuration
    }

    environment {
        NEXUS_BASE_URL   = "http://13.222.23.48:30881"
        NEXUS_REPO       = "maven-releases"
        NEXUS_DEPLOY_URL = "${NEXUS_BASE_URL}/repository/${NEXUS_REPO}/"

        SONAR_HOST_URL   = "http://18.206.252.221"
        AWS_REGION       = "us-east-1"
        AWS_ACCOUNT_ID   = "615299740590"
        ECR_REPO         = "demo-sonar-repo"

        WORKSPACE_DIR    = "${env.WORKSPACE}"
    }

    triggers {
        githubPush()   // Auto-trigger on GitHub push
    }

    stages {

        stage('Prepare Workspace') {
            steps {
                echo "🧹 Fixing permissions..."
                sh 'sudo chown -R jenkins:jenkins $WORKSPACE_DIR || true'
                sh 'sudo chmod -R 755 $WORKSPACE_DIR || true'
            }
        }

        stage('Checkout Code') {
            steps {
                echo "📦 Checking out code from GitHub..."
                checkout scm
            }
        }

        stage('Code Scan (SonarQube)') {
            steps {
                echo "🔍 Running SonarQube code analysis..."
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
                echo "🏗️ Building JAR package..."
                sh 'mvn -B clean package -DskipTests=true'
            }
        }

        stage('Store Artifacts in Nexus') {
            steps {
                echo "⬆️ Uploading artifacts to Nexus..."
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
                    echo "🐳 Building Docker image and pushing to ECR..."
                    def ecrUri = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

                    withAWS(credentials: 'aws-ecr-creds', region: "${AWS_REGION}") {
                        sh """
                            # 1. Ensure ECR repo exists
                            aws ecr describe-repositories --repository-names ${ECR_REPO} || \
                                aws ecr create-repository --repository-name ${ECR_REPO}

                            # 2. Login to ECR
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                            # 3. Build Docker image using the existing Dockerfile in repo
                            docker build -t ${ECR_REPO}:${GIT_COMMIT} .

                            # 4. Tag for commit and latest
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:${GIT_COMMIT}
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:latest

                            # 5. Push both tags
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
            echo "✅ Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed. Check logs above for exact issue."
        }
    }
}
