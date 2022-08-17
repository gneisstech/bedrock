#!/usr/bin/python3
import sys
import yaml

#Grab the first argument
template_option = sys.argv[1] if len(sys.argv) == 2 else ''
if template_option not in ['ci', 'dev']:
    print("""Invalid option or number of arguments.

Usage: yaml_filler.py [OPTION]
Fill in the template.yaml with values depending on deployment option.

Options:
  ci     fill out the template using the ci values
  dev    fill out the template using the dev values
    """)

template = yaml.safe_load(open('template.yaml'))

env = 'dev'
resource_group = {'name': "&brWafRG 'Waf-brdev'", 'action': 'read'}
paas_purge = 'true'
keyvault = {'name': "&persistentKVName '##app##-dev-master-kv'",
	        'action': 'read'}
seed_value = '*persistentKVName'
	        
if template_option == 'ci':
    env = 'ci'
    resource_group = {'name': "&brWafRG 'Waf-##appenv##'", 'action': 'create'}
    paas_purge = 'false'
    keyvault = None
    seed_value = '*kvName'


template['target']['env'] = env
template['target']['iaas']['resource_groups'].insert(0, resource_group)
template['target']['paas']['keyvaults'][0]['purge'] = paas_purge
if keyvault: template['target']['paas']['keyvaults'].append(keyvault)
seed_values = template['target']['saas']['helm']['default_values']['secrets']['seed_values']
for seed_val in seed_values:
    seed_val['source']['vault_name'] = seed_value

filename = 'br_k8s_ci.yaml' if template_option == 'ci' else 'br_k8s_dev.yaml'
with open(filename, 'w') as out_file:
    out_file.write(yaml.dump(template))
