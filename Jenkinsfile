#!groovy
pipeline {
  agent {
    docker {
      image 'docker'
    }
  }
  
  stages {
    stage('Check for Latest Commit') {
      steps {
        script {
          def latestCommit = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
          def hasLatestCommit = false
          
          // Check if there is a newer commit in the Git repository
          if (latestCommit != sh(script: 'git rev-parse origin/master', returnStdout: true).trim()) {
            hasLatestCommit = true
          }
          
          // Proceed to the next stage if there is a latest commit
          if (hasLatestCommit) {
            checkout scm
          } else {
            echo 'No latest commit. Skipping the next stage.'
            currentBuild.result = 'SUCCESS'
            return
          }
        }
      }
    }
    
    stage('Terraform Apply') {
      steps {
        sh 'terraform init'
        sh 'terraform apply -auto-approve'
      }
    }
    
    stage('Install Jenkins and Nginx') {
      steps {
        ansiblePlaybook(
          playbook: 'path/to/ansible/playbook.yml',
          inventory: 'path/to/ansible/inventory.ini',
          
        )
      }
    }
  }
}
