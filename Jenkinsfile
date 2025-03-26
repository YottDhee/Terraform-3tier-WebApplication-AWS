pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }

    stages {
        stage('Checkout Code') {
            steps {
                script {
                     checkout scm
                }
            }
        }

        stage('Setup and Initialize Terraform') {
            steps {
                script {
                    dir('terraformFiles') { 
                        sh 'terraform init'
                    }
                }
            }
        }

        stage('Validate and Format Terraform') {
            steps {
                script {
                    dir('terraformFiles') { 
                        sh '''
                        terraform validate
                        terraform fmt
                        terraform plan -out=tfplan
                        '''
                    }
                }
            }
        }

        stage('Plan Terraform') {
            steps {
                script {
                    dir('terraformFiles') { 
                        sh 'terraform plan -out = tfplan'
                    }
                }
            }
        }

        stage('Apply Terraform') {
            when {
                branch 'main'
            }
            steps {
                script {
                    dir('terraformFiles') { 
                        sh 'terraform apply -auto-approve tfplan'
                    }
                }
            }
        }

        stage('Extract Terraform Outputs') {
            steps {
                script {
                    dir('terraformFiles') { 
                    sh '''
                        terraform output -json > terraform-outputs.json
                        jq -r "to_entries|map(\\\"\\(.key)=\\(.value.value)\\\")|.[]" terraform-outputs.json > .env
                    '''
                    }
                }
            }
        }

        stage('Deploy Backend') {
            steps {
                script {
                    sh '''
                    PRIVATE_IP=$(terraform -chdir=terraformFiles output -raw App_ip)

                    # Copy the .env file to the private instance
                    scp -o StrictHostKeyChecking=no .env ec2-user@$PRIVATE_IP:/home/ec2-user/app/.env
                    
                    # SSH into the private instance and deploy the backend
                    ssh -o StrictHostKeyChecking=no ec2-user@$PRIVATE_IP << 'EOF'
                        cd /home/ec2-user/app
                        npm install
                        pm2 restart server.js || pm2 start server.js
                    EOF
                    '''
                }
            }
        }
        
        stage('Deploy HTML to S3') {
            steps {
                script {
                    sh 'aws s3 sync ./html s3://tf3tierbucket --delete'
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline execution completed'
        }
        success {
            echo 'Deployment Successful!'
        }
        failure {
            echo 'Deployment Failed!'
        }
    }
}
