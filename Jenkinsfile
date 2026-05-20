pipeline {
    agent any

    environment {
        REPO_URL      = "https://github.com/sathish19120/Finance-APP.git"
        IMAGE_NAME    = "finance-app"
        IMAGE_TAG     = "${env.BUILD_NUMBER}"
        SONAR_SERVER  = "SonarQubeLocal"
        ARTIFACT_CONTAINER = "artifactory"
        PORTAL_CONTAINER   = "web-portal"
        K8S_NAMESPACE = "default"
    }

    triggers {
        githubPush()
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: "${REPO_URL}"
                echo "Repo: sathish19120/Finance-APP"
                echo "Build #${env.BUILD_NUMBER} | Commit: ${env.GIT_COMMIT}"
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv("${SONAR_SERVER}") {
                    sh """
                        sonar-scanner \
                          -Dsonar.projectKey=Finance-APP \
                          -Dsonar.projectName="Finance APP" \
                          -Dsonar.sources=. \
                          -Dsonar.inclusions=**/*.html,**/*.js,**/*.css \
                          -Dsonar.exclusions=node_modules/**,k8s/** \
                          -Dsonar.host.url=${SONAR_HOST_URL} \
                          -Dsonar.login=${SONAR_AUTH_TOKEN}
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh """
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                    echo "Image built: ${IMAGE_NAME}:${IMAGE_TAG}"
                """
            }
        }

        stage('Save to Artifactory') {
            steps {
                sh """
                    mkdir -p /tmp/artifacts
                    docker save ${IMAGE_NAME}:${IMAGE_TAG} | gzip > /tmp/artifacts/${IMAGE_NAME}-${IMAGE_TAG}.tar.gz
                    docker cp /tmp/artifacts/${IMAGE_NAME}-${IMAGE_TAG}.tar.gz \
                        ${ARTIFACT_CONTAINER}:/usr/share/nginx/html/artifacts/
                    echo "Saved to Artifactory: ${IMAGE_NAME}-${IMAGE_TAG}.tar.gz"
                """
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh """
                    kubectl apply -f k8s/deployment.yaml  -n ${K8S_NAMESPACE}
                    kubectl apply -f k8s/service.yaml     -n ${K8S_NAMESPACE}
                    kubectl apply -f k8s/hpa.yaml         -n ${K8S_NAMESPACE}

                    kubectl set image deployment/finance-app \
                        finance-app=${IMAGE_NAME}:${IMAGE_TAG} \
                        -n ${K8S_NAMESPACE}

                    kubectl rollout status deployment/finance-app \
                        -n ${K8S_NAMESPACE} --timeout=120s
                """
            }
        }

        stage('Smoke Test') {
            steps {
                sh """
                    echo "Waiting for pods to be ready..."
                    sleep 15
                    curl -sf http://localhost:30080 | grep -i finance || \
                    curl -sf http://localhost:30080/index.html || \
                    (echo "Smoke test failed" && exit 1)
                    echo "Smoke test passed - app is live at http://localhost:30080"
                """
            }
        }
    }

    post {
        success {
            echo """
            ========================================
            DEPLOYMENT SUCCESSFUL
            App       : http://localhost:30080
            Artifact  : http://localhost:8082/artifacts/${IMAGE_NAME}-${IMAGE_TAG}.tar.gz
            SonarQube : http://localhost:9000/dashboard?id=Finance-APP
            ========================================
            """
        }
        failure {
            sh """
                echo "Rolling back deployment..."
                kubectl rollout undo deployment/finance-app -n ${K8S_NAMESPACE} || true
            """
        }
        always {
            sh "rm -rf /tmp/artifacts"
            cleanWs()
        }
    }
}
