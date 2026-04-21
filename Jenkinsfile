pipeline {
    agent any

    environment {
        APP_NAME   = 'stock-predictor'
        MAVEN_OPTS = '-Xmx512m'
    }

    options {
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        stage('Build') {
            steps {
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
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        /opt/maven/bin/mvn sonar:sonar \
                            -Dsonar.projectKey=stock-predictor \
                            -Dsonar.projectName="Stock Options Predictor" \
                            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                            -Dsonar.scm.disabled=true \
                            -B
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${APP_NAME}:${BUILD_NUMBER} ."
                sh "docker tag  ${APP_NAME}:${BUILD_NUMBER} ${APP_NAME}:latest"
            }
        }

        stage('Deploy') {
            steps {
                // Single quotes prevent Groovy interpolation.
                // This avoids the {{ }} Go template syntax being
                // misinterpreted by the Groovy parser.
                sh '''
                    docker stop stock-predictor || true
                    docker rm   stock-predictor || true

                    docker run -d \
                        --name stock-predictor \
                        --network tus_stp_cbd_sem2_4_2026_cicd \
                        -p 8080:8080 \
                        --restart unless-stopped \
                        stock-predictor:latest

                    echo "Waiting for application to start..."
                    sleep 30

                    curl --fail http://stock-predictor:8080/actuator/health
                    echo "Deployment successful."
                '''
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