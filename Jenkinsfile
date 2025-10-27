pipeline {
    agent any

    tools {
        maven 'Maven3'   // Must match Maven installation name in Jenkins global tools
        jdk 'Java17'     // Must match JDK installation name in Jenkins global tools
    }

    environment {
        // ------------------- Nexus Config -------------------
        NEXUS_BASE_URL   = "http://13.222.23.48:30881"     // Nexus service NodePort or LoadBalancer URL
        NEXUS_REPO       = "maven-releases"                // Change to 'maven-snapshots' if using snapshot version
        NEXUS_DEPLOY_URL = "${NEXUS_BASE_URL}/repository/${NEXUS_REPO}/"

        // ------------------- SonarQube Config -------------------
        SONAR_HOST_URL = "http://18.206.252.221"

        // ------------------- AWS Config -------------------
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
                echo "Fixing file permissions for Jenkins workspace..."
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
                echo "Building Maven project..."
                sh 'mvn -B clean package -DskipTests=true'
            }
        }

        stage('Store Artifacts in Nexus') {
            steps {
                echo "Deploying artifacts to Nexus..."
                withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    sh '''
                        mvn -B deploy -DskipTests=true \
                            -DaltDeploymentRepository=nexus::default::${NEXUS_DEPLOY_URL} \
                            -Dnexus.username=${NEXUS_USER} \
                            -Dnexus.password=${NEXUS_PASS}
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
                            aws ecr describe-repositories --repository-names ${ECR_REPO} || \
                                aws ecr create-repository --repository-name ${ECR_REPO}

                            echo "Logging in to ECR..."
                            aws ecr get-login-password | docker login --username AWS --password-stdin ${ecrUri}

                            echo "Building Docker image..."
                            docker build -t ${ECR_REPO}:${GIT_COMMIT} .

                            echo "Tagging and pushing Docker image..."
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:${GIT_COMMIT}
                            docker push ${ecrUri}:${GIT_COMMIT}

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
            echo "✅ Pipeline completed successfully — build, scan, deploy, and push done!"
        }
        failure {
            echo "❌ Pipeline failed. Check the logs for error details."
        }
    }
}
