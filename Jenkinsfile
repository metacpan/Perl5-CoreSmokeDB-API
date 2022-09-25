#! Groovy

pipeline {
    agent { label 'perl5smokedb' }
    environment {
        PGHOST='fidodbmaster'
    }
    stages {
        stage('Build_and_Test') {
            steps {
                script { echo "Building and testing branch: " + scm.branches[0].name }
                sh '''
cpanm --notest -L local --installdeps .
cpanm --notest -L local TAP::Formatter::JUnit
prove -Ilocal/lib/perl5 --formatter=TAP::Formatter::JUnit --timer -wl t/ > testout.xml
                '''
                archiveArtifacts artifacts: 'local/**, lib/**, environments/**, config.yml, bin/**'
            }
            post {
                changed {
                    junit 'testout.xml'
                }
            }
        }
        stage('MergeConfig') {
            steps {
                step([$class: 'WsCleanup'])
                unarchive  mapping: ['**': 'deploy/']
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [[
                        $class: 'RelativeTargetDirectory',
                        relativeTargetDir: 'configs'
                    ]],
                    submoduleCfg: [],
                    userRemoteConfigs: [[
                        credentialsId: '6ad81623-70f5-4d1c-8631-9015178ff4c9',
                        url: 'ssh://git@source.test-smoke.org:9999/~/ztreet-configs'
                    ]]
                ])
                sh '''
cp -v configs/Perl5-CoreSmokeDB-API/preview.yml deploy/environments/
cp -v configs/Perl5-CoreSmokeDB-API/production.yml deploy/environments/
chmod +x deploy/local/bin/*
                '''
                archiveArtifacts artifacts: 'deploy/**'
                script {
                    echo "Merged configs for: ${env.BRANCH_NAME}" + scm.branches[0].name
                }
            }
        }
        stage('DeployPreview') {
            when {
                // branch 'preview'
                expression {
                    echo "BRANCH_NAME is ${scm.branches[0].name}"
                    return scm.branches[0].name == "preview"
                }
            }
            steps {
                sh 'chmod +x deploy/local/bin/*'
                sshagent(['ssh-deploy']) {
                    sh '''
/usr/bin/deploy -av deploy/ perl5smokedb.fritz.box:/var/lib/www/Perl5-CoreSmokeDB-API.preview/
/usr/bin/restart-remote perl5smokedb.fritz.box perl5smokedb-preview
                    '''
                }
            }
        }
    }
}
