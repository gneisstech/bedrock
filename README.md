# bedrock

infrastructure as code;  bring your own application

keep it simple.  keep it boring.  keep it DRY

1. boring tooling to build and deploy IaaS, PaaS clusters using Kubernetes (K8S) on various cloud providers and edge gateways
1. boring tooling to maintain hierarchical HELM charts and auto update their semver and deployment packaging based on
   1. semver changes of included services or charts;
   1. changes to list of included services or charts (added or dropped dependencies)
1. boring tooling for container management
   1. maintain semver
   1. add metadata for audit and tracability
      1. source repository
      1. commit SHA
      1. semver tagging
      1. available configuration environment variables
      1. openapi spec
   1. standardized entry points for test and deployment operations
      1. unit test
      1. static analysis
      1. dynamic analysis
      1. data model migration

Target Platforms:
1. Various cloud providers (Azure, AWS, GCP)
1. Local Host

Issue Tracker: https://gitlab.com/abltech/bedrock/-/issues

The "BeachHead" cluster example

The "SunnyDay" sample application

Kitchen sink included.
- sample observability platform integration
  - labelling and tagging of resources for observability bucketing
- sample security configuration
  - cluster RBAC
    - Namespaces
    - service principals
    - control plane APIs
  - container firewall
  - container CVE check admission controller
  - active Intrusion Detection and Prevention integation
  - encryption of data in motion
  - automation rotation of public facing TLS certificates
    - LetsEncrypt/ACME protocol
  - run all containers from your own container registry
  - access to internal applications (security, observability, k8s dashboard)
    - restricted to cluster operators who can `kubectl port-forward` to the front end for those services
- networking
  - encryption of data in motion
  - isolated zones with RBAC access
  - isolated DNS namespaces with RBAC access
  - internal loadbalancers for services
  - external loadbalancers for web firewall function
- autoscale horizontally for cpu, memory, pod capacity
- sample application with Web Firewall Ingress supporting:
  - Federation of OpenID compliant Identity providers
  - Web Application Firewall with
    - 1st class kubernetes Ingress services
    - DDOS defense measures
    - OWASP rule sets - blocking mode only
    - security headers
    - limit TLS supported protocols
    - limit TLS supported cryptographic suites
    - Payload sizes
    - Rate Limit

Work in process:
- near term goals
  - refactor all recipes to support json argument package
  - provide recipes for additional cloud Platforms
  - create custom kubernetes operators for
    - IaaS resources and,
    - PaaS managed services from a cloud provider
    - Local devices on edge controllers
      - USB
      - Ethernet resources
      - BacNet
      - others

General philosophies:
- Scaling
  - scale horizontally to meet your SLA (more nodes from your service provider)
    - your app must still run with N-1 nodes
    - your app must still run when a service provider loses a node, rack or datacenter
  - scale vertically (larger nodes from your service provider)
    - until no larger nodes are available, or
    - the time taken to populate the new node with pods is too long for your SLA
    - then, scale horizontally for N+`ZZ` redundancy where (`time to populate pods on new node` / `ZZ` ) works for your SLA
      - continue scaling vertically
  - scale horizontally until your provider doesn't let you
- Clustering
  - when to create a new cluster
    - isolation needed for cost tracking
    - need to limit the "blast radius" of failed services
    - need to limit the "blast radius" of sophisticated intruders who can break into the hypervisor infrastructure
    - need for multi-cloud provider distribution of services
    - your provider will not let you scale to more resources in that cluster
    - latency reduction for control plane operations across geographic regions
- Namespaces
  - when to create new Namespaces
    - isolate development users from each others
    - isolate different logical domains in an architecture
    - isolate different architectures from each other
    - when security similar to a VLAN or Network Security Group is needed
    - when isolation of resources is required for security concerns
    - when separation of resources facilitates different lifecycles

```

# Copyright (c) 2016-2017, techguru@byiq.com
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
