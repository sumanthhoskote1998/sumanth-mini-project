pipeline {
    agent any

    tools {
        maven 'Maven3'     // Jenkins global tool name
        jdk 'Java17'       // Jenkins global tool name
    }

    environment {
        // ------------------- Nexus Config -------------------
        NEXUS_BASE_URL   = "http://13.222.23.48:30881"
        NEXUS_REPO       = "maven-releases"
        NEXUS_DEPLOY_URL = "${NEXUS_BASE_URL}/repository/${NEXUS_REPO}/"

        // ------------------- SonarQube Config -------------------
        SONAR_HOST_URL = "http://18.206.252.221"

        // ------------------- AWS Config -------------------
        AWS_REGION     = "us-east-1"
        AWS_ACCOUNT_ID = "615299740590"
        ECR_REPO       = "demo-sonar-repo"
    }

    triggers {
        githubPush()
    }

    stages {

        stage('Prepare Workspace') {
            steps {
                echo "Fixing permissions for workspace..."
                sh '''
                    sudo chown -R jenkins:jenkins $WORKSPACE || true
                    sudo chmod -R 755 $WORKSPACE || true
                '''
            }
        }

        stage('Checkout Code') {
            steps {
                echo "Cloning GitHub repository (main branch)..."
                git branch: 'main',
                    url: 'https://github.com/sumanthhoskote1998/sumanth-mini-project.git'
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
                echo "Building the Maven project..."
                sh 'mvn -B clean package -DskipTests=true'
                sh 'ls -l target/'
            }
        }

        stage('Upload Artifact to Nexus') {
            steps {
                echo "Uploading JAR to Nexus repository..."
                withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    sh '''
                        ARTIFACT_PATH=$(find target -name "*.jar" | head -n 1)
                        if [ -f "$ARTIFACT_PATH" ]; then
                            curl -v -u ${NEXUS_USER}:${NEXUS_PASS} \
                              --upload-file "$ARTIFACT_PATH" \
                              ${NEXUS_DEPLOY_URL}com/example/demo-sonar-nexus-ecr/0.1.0/demo-sonar-nexus-ecr-0.1.0.jar
                        else
                            echo "❌ JAR file not found in target/. Build step may have failed."
                            exit 1
                        fi
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
                            echo "Ensuring ECR repository exists..."
                            aws ecr describe-repositories --repository-names ${ECR_REPO} >/dev/null 2>&1 || \
                              aws ecr create-repository --repository-name ${ECR_REPO}

                            echo "Logging in to ECR..."
                            aws ecr get-login-password | docker login --username AWS --password-stdin ${ecrUri}

                            echo "Building Docker image..."
                            docker build -t ${ECR_REPO}:${BUILD_NUMBER} .

                            echo "Tagging and pushing Docker image..."
                            docker tag ${ECR_REPO}:${BUILD_NUMBER} ${ecrUri}:${BUILD_NUMBER}
                            docker push ${ecrUri}:${BUILD_NUMBER}

                            docker tag ${ECR_REPO}:${BUILD_NUMBER} ${ecrUri}:latest
                            docker push ${ecrUri}:latest
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completed successfully — code scanned, built, uploaded to Nexus, and image pushed to ECR!"
        }
        failure {
            echo "❌ Pipeline failed. Please check above logs for the error details."
        }
    }
}
