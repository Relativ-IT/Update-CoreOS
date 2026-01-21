Boolean Updated = false;

pipeline {
  triggers {
    cron(env.BRANCH_NAME == 'main' ? 'H H * * 3' : '')
  }

  agent {
    label 'Linux'
  }

  environment {
      ARTEFACTS_PATH = "/media/img/coreos"
      ARTEFACTS_VERSIONS = "coreos.json"
  }

  stages {
    stage('Initialize') {
      parallel {
        stage('Advertise start of build') {
          steps {
            slackSend color: "#4675b1", message: "${env.JOB_NAME} build #${env.BUILD_NUMBER} started :fire: (<${env.RUN_DISPLAY_URL}|Open>)"
          }
        }

        stage('Print environments variables') {
          steps {
            sh 'printenv | sort'
          }
        }
      }
    }

    stage('Set up prerequisites') {
      parallel {
        stage('Get ssh host key') {
          steps {
            sh '''
              [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh && touch ~/.ssh/known_hosts
              if !(ssh-keygen -F $ARTEFACT_SERVER)
              then
                ssh-keyscan -t ed25519 $ARTEFACT_SERVER >> ~/.ssh/known_hosts
              fi
            '''
          }
        }

        stage('Get fedora pgp keys') {
          steps {
            sh 'curl --no-progress-meter https://fedoraproject.org/fedora.gpg | gpg --import'
          }
        }

        stage('Get last version') {
          steps {
            sshagent(credentials: ['Jenkins-Key']) {
              sh '''
                if scp jenkins@$ARTEFACT_SERVER:/$ARTEFACTS_PATH/$ARTEFACTS_VERSIONS ./$ARTEFACTS_VERSIONS
                  then
                    echo "History found"
                  else
                    echo "History not found"
                  fi
              '''
            }
          }
        }
      }
    }

    stage("Download ... Upload") {
      matrix {
        axes { 
          axis {
            name 'STREAM'
            values 'stable', 'next', 'testing'
          }
          axis {
            name 'ARCH'
            values 'x86_64', 'aarch64'
          }
          axis {
            name 'ARTIFACT'
            values 'metal'
          }
          axis {
            name 'FORMAT'
            values 'pxe'
          }
        }

        excludes {
          exclude {
            axis {
              name 'STREAM'
              values 'testing'
            }
          }

          exclude {
            axis {
              name 'ARCH'
              values 'aarch64'
            }
          }
        }

        stages {
          stage("Getting CoreOS artefacts") {
            steps {
              sh './Update.sh --stream $STREAM --arch $ARCH --artifact $ARTIFACT --format $FORMAT --history $ARTEFACTS_VERSIONS --verbose true'
            }
          }

          stage("Upload Files") {
            when { expression { fileExists("${FORMAT}.${ARTIFACT}.${ARCH}.${STREAM}") } }
            steps {
              sshagent(credentials: ['Jenkins-Key']) {
                sh '''
                  files=$(cat $FORMAT.$ARTIFACT.$ARCH.$STREAM)
                  ssh jenkins@$ARTEFACT_SERVER "sh -c 'for f in /media/img/coreos/*.$STREAM ; do mv -- \$f \${f%.$STREAM}.$STREAM.previous; done'"
                  echo uploading $FORMAT.$ARTIFACT.$ARCH.$STREAM files
                  scp $files jenkins@$ARTEFACT_SERVER:/media/img/coreos/
                '''
                script { Updated = true }
              }
            }
          }
        }
      }
    }

    stage("Upload versions update") {
      when { expression { Updated == true } }
      steps {
        sshagent(credentials: ['Jenkins-Key']) {
          sh '''
            scp ./$ARTEFACTS_VERSIONS jenkins@$ARTEFACT_SERVER:/$ARTEFACTS_PATH/$ARTEFACTS_VERSIONS
          '''
          archiveArtifacts ARTEFACTS_VERSIONS
        }
      }
    }
  }

  post {
    success {
      slackSend color: "#4675b1", message: "${env.JOB_NAME} successfully built :blue_heart: !"
    }

    failure {
      slackSend color: "danger", message: "${env.JOB_NAME} build failed :poop: !"
    }

    cleanup {
      cleanWs()
    }
  }
}
