# bedrock

infrastructure as code;

keep it simple.  keep it boring.  keep it DRY

1. simple tooling to build and deploy IaaS, PaaS clusters using Kubernetes (K8S) on various cloud providers and edge gateways
1. simple tooling to maintain hierarchical HELM charts and auto update their semver and deployment packaging based on
   1. semver changes of included services or charts;
   1. changes to list of included services or charts (added or dropped dependencies)

Target Platforms:
1. Various cloud providers (Azure, AWS, GCP)
1. Local Host

Issue Tracker: https://gitlab.com/abltech/bedrock/-/issues

The "BeachHead" cluster example

```
#
# Copyright (c) 2017-2019, Cloud Scaling
# Copyright (c) 2019-2020, Acuity Brands Lighting Inc.
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
```