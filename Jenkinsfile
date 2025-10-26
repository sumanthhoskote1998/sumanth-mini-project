pipeline {
    agent any

    environment {
        // === Nexus Repository Details ===
        NEXUS_URL  = "http://44.211.151.128:30881/repository/maven-releases/"
        
        // === SonarQube ===
        SONAR_HOST_URL = "http://34.205.140.154:30001/"

        // === AWS ECR ===
        AWS_REGION     = "us-east-1"
        AWS_ACCOUNT_ID = "615299740590"
        ECR_REPO       = "demo-sonar-repo"
    }

    triggers {
        githubPush()
    }

    stages {
        // ---------------------------------
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        // ---------------------------------
        stage('Code Scan (SonarQube)') {
            steps {
                withSonarQubeEnv('SonarQube') { // Use your SonarQube server name from Jenkins config
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

        // ---------------------------------
        stage('Build Application') {
            steps {
                sh 'mvn -B -DskipTests=false package'
            }
        }

        // ---------------------------------
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

        // ---------------------------------
        stage('Docker Build & Push to AWS ECR') {
            steps {
                script {
                    def ecrUri = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
                    withAWS(credentials: 'aws-ecr-creds', region: "${AWS_REGION}") {
                        sh '''
                            # Ensure ECR repo exists
                            aws ecr describe-repositories --repository-names ${ECR_REPO} || \
                                aws ecr create-repository --repository-name ${ECR_REPO}

                            # Login to ECR
                            aws ecr get-login-password | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                            # Build Docker image
                            docker build -t ${ECR_REPO}:${GIT_COMMIT} .

                            # Tag image
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:${GIT_COMMIT}
                            docker tag ${ECR_REPO}:${GIT_COMMIT} ${ecrUri}:latest

                            # Push images
                            docker push ${ecrUri}:${GIT_COMMIT}
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
