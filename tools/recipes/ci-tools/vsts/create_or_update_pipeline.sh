#!/usr/bin/env bash

#
# Maintainer: techguru@byiq.com
#
# Copyright (c) 2017-2019,  Cloud Scaling -- All Rights Reserved
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-/src}"

# Arguments
# ---------------------

function repo_root() {
  git rev-parse --show-toplevel
}

function place_holder() {
  cat <<EOF
  az pipelines list --organization https://dev.azure.com/ablcode --project bytelight -o table
Command
    az pipelines delete : Delete a pipeline.
        This command is in preview. It may be changed/removed in a future release.
Arguments
    --id      [Required] : ID of the pipeline.
    --detect             : Automatically detect organization.  Allowed values: false, true.
    --org --organization : Azure DevOps organization URL. You can configure the default organization
                           using az devops configure -d organization=ORG_URL. Required if not
                           configured as default or picked up via git config. Example:
                           https://dev.azure.com/MyOrganizationName/.
    --project -p         : Name or ID of the project. You can configure the default project using az
                           devops configure -d project=NAME_OR_ID. Required if not configured as
                           default or picked up via git config.
    --yes -y             : Do not prompt for confirmation.


Command
    az pipelines create : Create a new Azure Pipeline (YAML based).
        This command is in preview. It may be changed/removed in a future release.
Arguments
    --name           [Required] : Name of the new pipeline.
    --branch                    : Branch name for which the pipeline will be configured. If omitted,
                                  it will be auto-detected from local repository.
    --description               : Description for the new pipeline.
    --detect                    : Automatically detect organization.  Allowed values: false, true.
    --folder-path               : Path of the folder where the pipeline needs to be created. Default
                                  is root folder. e.g. "user1/test_pipelines".
    --org --organization        : Azure DevOps organization URL. You can configure the default
                                  organization using az devops configure -d organization=ORG_URL.
                                  Required if not configured as default or picked up via git config.
                                  Example: https://dev.azure.com/MyOrganizationName/.
    --project -p                : Name or ID of the project. You can configure the default project
                                  using az devops configure -d project=NAME_OR_ID. Required if not
                                  configured as default or picked up via git config.
    --queue-id                  : Id of the queue in the available agent pools. Will be auto
                                  detected if not specified.
    --repository                : Repository for which the pipeline needs to be configured. Can be
                                  clone url of the git repository or name of the repository for a
                                  Azure Repos or Owner/RepoName in case of GitHub repository. If
                                  omitted it will be auto-detected from the remote url of local git
                                  repository. If name is mentioned instead of url, --repository-type
                                  argument is also required.
    --repository-type           : Type of repository. If omitted, it will be auto-detected from
                                  remote url of local repository. 'tfsgit' for Azure Repos, 'github'
                                  for GitHub repository.  Allowed values: github, tfsgit.
    --service-connection        : Id of the Service connection created for the repository for GitHub
                                  repository. Use command az devops service-endpoint -h for
                                  creating/listing service_connections. Not required for Azure
                                  Repos.
    --skip-first-run --skip-run : Specify this flag to prevent the first run being triggered by the
                                  command. Command will return a pipeline if run is skipped else it
                                  will output a pipeline run.  Allowed values: false, true.
    --yaml-path --yml-path      : Path of the pipelines yaml file in the repo (if yaml is already
                                  present in the repo).

{
  "authoredBy": {
    "descriptor": "aad.MjU1ZjlkNGUtMTgxZC03ZjZjLTlhYWQtMTg5NGM4NWU4OTQ5",
    "directoryAlias": null,
    "displayName": "Sajin George",
    "id": "1ad86988-1183-4acf-9217-ef9ff49cbd76",
    "imageUrl": "https://ablcode.visualstudio.com/_apis/GraphProfile/MemberAvatars/aad.MjU1ZjlkNGUtMTgxZC03ZjZjLTlhYWQtMTg5NGM4NWU4OTQ5",
    "inactive": null,
    "isAadIdentity": null,
    "isContainer": null,
    "isDeletedInOrigin": null,
    "profileUrl": null,
    "uniqueName": "sxg08@acuitysso.com",
    "url": "https://spsprodeus21.vssps.visualstudio.com/A849c1808-a0cc-4df8-9c30-5c6daec4116c/_apis/Identities/1ad86988-1183-4acf-9217-ef9ff49cbd76"
  },
  "createdDate": "2019-10-23T18:26:38.080000+00:00",
  "draftOf": null,
  "drafts": [],
  "id": 94,
  "latestBuild": null,
  "latestCompletedBuild": null,
  "metrics": null,
  "name": "ByteLight_ble_app",
  "path": "\\",
  "project": {
    "abbreviation": null,
    "defaultTeamImageUrl": null,
    "description": null,
    "id": "707dc593-c3e1-4450-b166-e4b454b1e7e8",
    "lastUpdateTime": "2020-10-19T20:27:06.04Z",
    "name": "ByteLight",
    "revision": 4460,
    "state": "wellFormed",
    "url": "https://ablcode.visualstudio.com/_apis/projects/707dc593-c3e1-4450-b166-e4b454b1e7e8",
    "visibility": "private"
  },
  "quality": "definition",
  "queue": {
    "id": 64,
    "name": null,
    "pool": null,
    "url": "https://ablcode.visualstudio.com/_apis/build/Queues/64"
  },
  "queueStatus": "enabled",
  "revision": 137,
  "type": "build",
  "uri": "vstfs:///Build/Definition/94",
  "url": "https://ablcode.visualstudio.com/707dc593-c3e1-4450-b166-e4b454b1e7e8/_apis/build/Definitions/94?revision=137"
}
EOF
}

function create_or_update_pipeline() {
  true
}

create_or_update_pipeline "$@"
