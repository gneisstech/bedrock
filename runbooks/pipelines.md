# pipeline flow for dev to production [replicated for each source repository]

## developer - local

### edit->test [local native language server]

1) this path is for development of code functionality

### edit->test [containerized native language server]

1) this path is for testing of container, environment variables, some isolation from local machine
2) build container
3) mount local fs over container fs ... will see edit changes immediately
4) run tests against container endpoint

### edit->test [containerized native language server + firewalls/authn]

1) this path is for local e2e testing from  browser->firewall->authn proxy->container
2) deploy with docker-compose to ease connetions between containers

## developer commit

1) commits shall be to branches identified by ticket #, description
    1) branch name example "/topic/paulc/12345 - new dashboard widget"
    2) developer shall NOT rebase their branch with master

[[ @@ code review, pull request]]

[[ @@ notification on failure]]

[[ @@ branch naming master vs development]]

2) on commit, cloud pipeline shall run, producing at a minimum
    1) merge latest 'master' into topic branch
        1) developer to resolve any merge conflicts
        2) developer shall NOT rebase their branch with master
    2) static code analysis/SAST
    3) container build
    3) automated tests of container [SHALL be no regressions]
    4) test coverage metrics of container [SHALL be monotonic increasing]
    5) other automated review
        3) code quality
        4) SAST
        5) DAST
        6) automatic dependency scans
        7) automatic license compliance
        8) automatic container scanning
        9) automatic review
        11) automatic browser performance testing
        12) automatic monitoring
    6) success of all of the preceding will result in:
        1) deployment of container to DEV environment
        2) tagging of the branch tip
        3) merge of branch tip back to master branch
    7) automated tests of the dev environment endpoints
        1) on failure, container will be resubmitted to registry with "triage" tags
        1) on failure, container tags other than "triage" will be removed
3) master branch shall include all developer commits that have passed tests

## product manager -- commits

### product manager feature review

1) product manager may review features and patches on the dev environment
2) product manager will have tooling to "cherry pick" developer commits from a topic branch to the "staging" branch
3) any merge conflicts produced by the cherry pick must be resolved by the developer with additional commits on the topic branch
4) on commit of the cherry picked commits into the staging branch, cloud pipeline shall run, producing at a minimum
    2) static code analysis/SAST
    3) container build
    3) automated tests of container [SHALL be no regressions]
    4) test coverage metrics of container [SHALL be monotonic increasing]
    5) other automated review
        3) code quality
        4) SAST
        5) DAST
        6) automatic dependency scans
        7) automatic license compliance
        8) automatic container scanning
        9) automatic review
        11) automatic browser performance testing
        12) automatic monitoring
    6) success of all of the preceding will result in:
        1) tagging of the container as a release candidate
        2) deployment of container to Staging environment
        3) tagging of the branch tip as release candidate
        4) merge of branch tip back to master branch
    7) automated tests of the staging environment endpoints
        1) on failure, container will be resubmitted to registry with "triage" tags
        1) on failure, container tags other than "triage" will be removed

## product manager - submit to QA

1) product manager will have tooling to move the latest release candidate containers to QA
    1) release candidate container will be pulled from staging and pushed to QA environment

## QA release candidate promotion to production

1) the QA team will have tooling to move the latest release candidate containers to production
    1) release candidate container will be pulled from QA environment and pushed to production with new production tag


# data refresh

## on a regular basis, data shall be copied from production to staging

## on a regular basis, data shall be copied from staging to qa

## on a regular basis, data shall be copied from staging to dev


