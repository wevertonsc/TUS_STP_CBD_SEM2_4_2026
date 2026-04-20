pipeline {
    agent any

    environment {
        APP_NAME     = 'stock-predictor'
        APP_VERSION  = '1.0.0'
        DOCKER_IMAGE = "stock-predictor:${env.BUILD_NUMBER}"

        // SonarQube runs as a Docker Compose service named 'sonarqube'.
        // Inside the Docker network, Jenkins reaches it by service name.
        SONAR_HOST   = 'http://sonarqube:9000'
        SONAR_TOKEN  = credentials('sonar-token')

        // JDK 21 is pre-installed in the jenkins/jenkins:lts-jdk21 image.
        JAVA_HOME    = '/opt/java/openjdk'
        MAVEN_HOME   = '/opt/maven'
        PATH         = "/opt/maven/bin:${env.PATH}"
        MAVEN_OPTS   = '-Xmx512m'
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Cloning source repository...'
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        stage('Build') {
            steps {
                echo 'Compiling and packaging artefact...'
                sh 'mvn clean package -DskipTests -B'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Unit Tests') {
            steps {
                echo 'Running unit tests...'
                sh 'mvn test -B'
            }
            post {
                always {
                    junit 'target/surefire-reports/**/*.xml'
                }
            }
        }

        stage('Integration Tests') {
            steps {
                echo 'Running integration tests with Spring context...'
                sh 'mvn verify -B'
            }
            post {
                always {
                    junit allowEmptyResults: true,
                          testResults: 'target/failsafe-reports/**/*.xml'
                    jacoco(
                        execPattern:          'target/jacoco.exec',
                        classPattern:         'target/classes',
                        sourcePattern:        'src/main/java',
                        minimumLineCoverage:  '70'
                    )
                }
            }
        }

        stage('Code Quality - SonarQube') {
            steps {
                echo 'Running static code analysis...'
                withSonarQubeEnv('SonarQube') {
                    sh """
                        mvn sonar:sonar \
                            -Dsonar.projectKey=${APP_NAME} \
                            -Dsonar.projectName='Stock Options Predictor' \
                            -Dsonar.java.coveragePlugin=jacoco \
                            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                            -B
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                echo 'Waiting for SonarQube quality gate result...'
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image: ${DOCKER_IMAGE}"
                sh "docker build -t ${DOCKER_IMAGE} ."
                sh "docker tag ${DOCKER_IMAGE} ${APP_NAME}:latest"
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying containerised application...'
                sh """
                    docker stop ${APP_NAME} || true
                    docker rm   ${APP_NAME} || true
                    docker run -d \
                        --name ${APP_NAME} \
                        --network stock-predictor_default \
                        -p 8080:8080 \
                        --restart unless-stopped \
                        ${APP_NAME}:latest
                    echo 'Waiting for application to start...'
                    sleep 25
                    curl --fail http://localhost:8080/actuator/health || exit 1
                    echo 'Deployment successful.'
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully. Build: #${env.BUILD_NUMBER}"
        }
        failure {
            echo "Pipeline FAILED. Check the stage logs above."
        }
        always {
            cleanWs()
        }
    }
}
