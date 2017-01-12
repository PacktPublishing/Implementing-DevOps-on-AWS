#!groovy

node {

  stage "Checkout Git repo"
    checkout scm
  stage "Run tests"
    sh "docker run -v \$(pwd):/app --rm phpunit/phpunit tests/"
  stage "Build RPM"
    sh "[ -d ./rpm ] || mkdir ./rpm"
    sh "docker run -v \$(pwd)/src:/data/demo-app -v \$(pwd)/rpm:/data/rpm --rm tenzer/fpm fpm -s dir -t rpm -n demo-app -v \$(git rev-parse --short HEAD) --description \"Demo PHP app\" --directories /var/www/demo-app --package /data/rpm/demo-app-\$(git rev-parse --short HEAD).rpm /data/demo-app=/var/www/"
  stage "Update YUM repo"
    sh "[ -d ~/repo/rpm/demo-app/ ] || mkdir -p ~/repo/rpm/demo-app/"
    sh "mv ./rpm/*.rpm ~/repo/rpm/demo-app/"
    sh "createrepo ~/repo/"
    sh "aws s3 sync ~/repo s3://MY_BUCKET_NAME/ --region us-east-1 --delete"
  stage "Check YUM repo"
    sh "yum clean all"
    sh "yum info demo-app-\$(git rev-parse --short HEAD)"
}
