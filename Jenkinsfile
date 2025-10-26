pipeline {
    agent any

    tools {
        maven 'Maven3'   // Make sure you configured Maven in Jenkins global tools
        jdk 'Java17'     // Configure JDK in Jenkins global tools
    }

    environment {
        NEXUS_URL      = "http://44.211.151.128:30881/"
        NEXUS_REPO     = "maven-releases"
        SONAR_HOST_URL = "http://34.205.140.154:30001/"
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
                sh 'mvn -B clean package -DskipTests=false'
            }
        }

        stage('Store Artifacts in Nexus') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    sh '''
                        mvn -B deploy -DskipTests \
                            -DaltDeploymentRepository=nexus::default::${NEXUS_URL} \
                            -Dnexus.username=${NEXUS_USER} -Dnexus.password=${NEXUS_PASS}
                    '''
                }
            }
        }

        stage('Docker Build & Push to AWS ECR') {
            steps {
                script {
                    def ecrUri = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
                    withAWS(credentials: 'aws-ecr-creds', region: "${AWS_REGION}") {
                        sh '''
                            aws ecr describe-repositories --repository-names ${ECR_REPO} || \
                                aws ecr create-repository --repository-name ${ECR_REPO}

                            aws ecr get-login-password | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                            docker build -t ${ECR_REPO}:${GIT_COMMIT} .
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:${GIT_COMMIT}
                            docker push ${ecrUri}:${GIT_COMMIT}

                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:latest
                            docker push ${ecrUri}:latest
                        '''
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
