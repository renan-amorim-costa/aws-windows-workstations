// On-demand Windows workstation.
//
// This file IS the job: Jenkins reads it from the repository, so changing the
// pipeline is a commit - reviewable and reversible, like the Terraform.
//
// The job manages one workstation per run in a shared state. For several
// workstations at once, use workstations/terraform.tfvars directly.

pipeline {
    agent any

    parameters {
        string(name: 'NAME', defaultValue: 'demo',
               description: 'Workstation name: lowercase letters, digits and hyphens.')
        string(name: 'APPS', defaultValue: '7zip=24.08,webview2=latest,dbeaver=26.2.0',
               description: 'app=version, comma separated. Each installer must be in the catalog bucket.')
        booleanParam(name: 'MYSQL',     defaultValue: true,  description: 'MySQL database')
        booleanParam(name: 'SQLSERVER', defaultValue: false, description: 'SQL Server database (about 20 min to create)')
        booleanParam(name: 'POSTGRES',  defaultValue: false, description: 'PostgreSQL database')
        booleanParam(name: 'OPEN_RDP',  defaultValue: false,
                     description: 'Open RDP and the status page to this Jenkins public IP. Off: connect through SSM.')
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'],
               description: 'plan only shows. apply creates. destroy removes everything in the state.')
    }

    options {
        ansiColor('xterm')
        timestamps()
        // Two applies at once would fight over the state lock: queue them here.
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_INPUT         = '0'
    }

    stages {
        stage('Check parameters') {
            steps {
                script {
                    if (!(params.NAME ==~ /[a-z0-9-]+/)) {
                        error('NAME: lowercase letters, digits and hyphens only.')
                    }

                    def apps = []
                    for (item in params.APPS.split(',')) {
                        def parts = item.trim().split('=')
                        if (parts.length != 2) {
                            error("APPS: '${item}' is not app=version.")
                        }
                        apps << "\"${parts[0].trim()}\" = \"${parts[1].trim()}\""
                    }

                    def databases = []
                    if (params.MYSQL)     { databases << '"mysql"' }
                    if (params.SQLSERVER) { databases << '"sqlserver"' }
                    if (params.POSTGRES)  { databases << '"postgres"' }

                    env.APPS_HCL      = apps.join('\n      ')
                    env.DATABASES_HCL = databases.join(', ')
                }
            }
        }

        stage('Write variables') {
            steps {
                script {
                    def cidrs = '[]'
                    if (params.OPEN_RDP) {
                        def ip = sh(script: 'curl -s --max-time 10 https://checkip.amazonaws.com',
                                    returnStdout: true).trim()
                        cidrs = "[\"${ip}/32\"]"
                    }

                    writeFile file: 'workstations/jenkins.auto.tfvars', text: """\
# Written by Jenkins build ${env.BUILD_NUMBER} - do not edit.
catalog_bucket = "${env.CATALOG_BUCKET}"
key_name       = "${env.KEY_NAME}"
admin_cidrs    = ${cidrs}

workstations = {
  ${params.NAME} = {
    apps = {
      ${env.APPS_HCL}
    }
    databases = [${env.DATABASES_HCL}]
  }
}
"""
                    sh 'cat workstations/jenkins.auto.tfvars'
                }
            }
        }

        stage('Init') {
            steps {
                dir('workstations') {
                    sh '''
                        terraform init -no-color \
                          -backend-config="bucket=${TF_STATE_BUCKET}" \
                          -backend-config="key=aws-windows-workstations/workstations.tfstate" \
                          -backend-config="region=${AWS_REGION}" \
                          -backend-config="use_lockfile=true"
                    '''
                }
            }
        }

        stage('Plan') {
            steps {
                dir('workstations') {
                    sh 'terraform plan -no-color -out=tfplan'
                }
            }
        }

        stage('Apply') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                dir('workstations') {
                    sh 'terraform apply -no-color -auto-approve tfplan'
                    sh 'terraform output -no-color'
                }
            }
        }

        stage('Destroy') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                // A human confirms before anything is removed.
                timeout(time: 10, unit: 'MINUTES') {
                    input message: 'Destroy EVERYTHING in this state?', ok: 'Destroy'
                }
                dir('workstations') {
                    sh 'terraform destroy -no-color -auto-approve'
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f workstations/jenkins.auto.tfvars workstations/tfplan'
        }
    }
}
