pipeline {
    agent any

    environment {
        APP_NAME   = 'stock-predictor'
        MAVEN_OPTS = '-Xmx512m'
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
                sh '/opt/maven/bin/mvn clean package -DskipTests -B'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Unit Tests') {
            steps {
                sh '/opt/maven/bin/mvn test -B'
            }
            post {
                always {
                    junit testResults: 'target/surefire-reports/**/*.xml',
                          allowEmptyResults: true
                }
            }
        }

        stage('Integration Tests') {
            steps {
                sh '/opt/maven/bin/mvn verify -B'
            }
            post {
                always {
                    junit testResults: 'target/failsafe-reports/**/*.xml',
                          allowEmptyResults: true
                    jacoco(
                        execPattern:         'target/jacoco.exec',
                        classPattern:        'target/classes',
                        sourcePattern:       'src/main/java',
                        minimumLineCoverage: '70'
                    )
                }
            }
        }

        stage('Code Quality - SonarQube') {
            steps {
                // withSonarQubeEnv registers the analysis context that
                // waitForQualityGate requires. It must wrap the mvn call.
                // withCredentials injects the token as an env variable.
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh """
                            /opt/maven/bin/mvn sonar:sonar \
                                -Dsonar.token=${SONAR_TOKEN} \
                                -Dsonar.projectKey=${APP_NAME} \
                                -Dsonar.projectName='Stock Options Predictor' \
                                -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                                -B
                        """
                    }
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
                echo "Building Docker image: ${APP_NAME}:${BUILD_NUMBER}"
                sh "docker build -t ${APP_NAME}:${BUILD_NUMBER} ."
                sh "docker tag  ${APP_NAME}:${BUILD_NUMBER} ${APP_NAME}:latest"
            }
        }

        stage('Deploy') {
            steps {
                sh """
                    docker stop ${APP_NAME} || true
                    docker rm   ${APP_NAME} || true
                    docker run -d \
                        --name ${APP_NAME} \
                        -p 8080:8080 \
                        --restart unless-stopped \
                        ${APP_NAME}:latest
                    sleep 25
                    curl --fail http://localhost:8080/actuator/health
                """
            }
        }
    }

    post {
        success {
            echo "BUILD #${BUILD_NUMBER} PASSED"
        }
        failure {
            echo "BUILD #${BUILD_NUMBER} FAILED"
        }
    }
}