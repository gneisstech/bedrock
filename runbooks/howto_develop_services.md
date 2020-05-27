
make smoke_test

make deploy_local

make deploy_dev_azure [ breaking change, new feature, patch ]
    git tag new semver
    update docker container semver
    update helm chart contents
    update helm chart semver
    push service chart
    deploy umbrella chart to developer's namespace
    smoke_test
    
make promote_dev_azure
    smoke_test
    git tag new semver [RC]
    update docker container semver [RC]
    update helm chart contents
    update helm chart semver [RC]

    