@Library('shared-library') _

pipeline {

  agent { label 'erlang' }
  environment {
    NEXUS_DOCKER_URL = '10.20.3.49:8083'
    NEXUS_DOCKER_REPO = 'onextel'
    IMAGE_NAME = 'registry'
    IMAGE_TAG = "${BUILD_NUMBER}"
    FULL_IMAGE_BUILD = "${NEXUS_DOCKER_URL}/${NEXUS_DOCKER_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"
    FULL_IMAGE_LATEST = "${NEXUS_DOCKER_URL}/${NEXUS_DOCKER_REPO}/${IMAGE_NAME}:latest"
  }


  stages {
    stage('Checkout') {
      steps {
        branchCheckout()
      }
    }

    stage('list files') {
      steps {
        sh 'ls -la'
        sh 'id'
      }
    }

    stage('Build') {
      steps {
        // sh './build.sh'
        sh 'bash -i -c "rebar3 release"'
      }
    }
    stage('Generate base registry Image') {
      steps {
        sh 'docker build -t registry:${BUILD_NUMBER} .'
      }
    }
    // stage('Tag image as latest') {
    //   steps {
    //     sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest"
    //   }
    // }
    stage('Tag & Push Image to Nexus') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'NexusCred', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
          sh """
            echo '🔑 Logging into Nexus Docker repo...'
            echo "\$NEXUS_PASS" | docker login ${NEXUS_DOCKER_URL} -u "\$NEXUS_USER" --password-stdin

            echo '🏷️ Tagging images for Nexus...'
            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_BUILD}
            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_LATEST}

            echo '🚀 Pushing build tag to Nexus...'
            docker push ${FULL_IMAGE_BUILD}

            echo '🚀 Pushing latest tag to Nexus...'
            docker push ${FULL_IMAGE_LATEST}
          """
        }
      }
    }

    stage('Clean intermediate images') {
      steps {
            sh "docker image rm ${IMAGE_NAME}:${IMAGE_TAG} || true"
            sh "docker image rm ${IMAGE_NAME}:latest || true"
            sh "docker image rm ${FULL_IMAGE_BUILD} || true"
            sh "docker image rm ${FULL_IMAGE_LATEST} || true"
      }
    }

  }
}
