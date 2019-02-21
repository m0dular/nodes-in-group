#!/bin/bash

fail() {
   echo "$@"
   exit 1
}

get_nodes() {
   local group="$1"; local rule="$2"

   [[ $group && $rule ]] || fail "Error getting rule. Make sure the $group node group exists"

   # Translate it into something the /nodes enpoint can use
   translated_rule="$(curl -s -X POST --cert $puppet_host_cert --key $puppet_host_key --cacert $puppet_local_cert \
      "https://$puppet_server:4433/classifier-api/v1/rules/translate" -H 'Content-Type: application/json' --data "$rule" | \
      jq -c '.query')"

   [[ $translated_rule ]] || fail "Error translating rule"

   # Get the node list and dump it to the temp file
   if [[ $rule == "null" ]]; then
      nodes=()
   else
      nodes=($(curl -s --cert $puppet_host_cert --key $puppet_host_key --cacert $puppet_local_cert -G \
         "https://$puppet_server:8081/pdb/query/v4/nodes" --data-urlencode "query=$translated_rule" | jq -rc '.[] | .certname'))
   fi

   # Use jq to parse raw input and turn it into valid json
   printf '%s\n%s\n' "$group" "${nodes[@]}" | sed '/^$/d' | jq -Rn '[{key: input, value: [inputs]}] | from_entries' >>"$_tmp"
}

usage() {
   cat <<EOF
Usage: $0 <group name>
	<group name> defaults to all groups if empty
EOF
   exit 1
}

trap fail ERR
_tmp="$(mktemp)"

# If we got too many arguments or --help
(( $# > 1 )) || [[ $@ =~ --help ]] && usage

# Variables to use in `curl`
puppet_server="$(puppet config print server)"
puppet_host_cert="$(puppet config print hostcert)"
puppet_host_key="$(puppet config print hostprivkey)"
puppet_ca_cert="$(puppet config print cacert)"
puppet_local_cert="$(puppet config print localcacert)"

# Ensure the `puppet config print`s worked
for f in ${!puppet*}; do
   [[ ${!f} ]] || fail "Error setting $f"
done

# Get the rule(s) from the classifier api
if (( $# > 0 )); then
   mapfile -t lines < <(curl -s https://$puppet_server:4433/classifier-api/v1/groups --cert \
      $puppet_host_cert --key $puppet_host_key --cacert $puppet_ca_cert | jq -rc ".[] | select(.name == \"$1\") | .name, .rule"
   )
   (( ${#lines[@]} > 0 )) || {
      fail "Error getting groups from the classifier api." \
      "Please ensure this is run on a Puppet master and that $1 is a valid node group"
   }

   get_nodes "${lines[@]}"
else
   mapfile -t lines < <(curl -s https://$puppet_server:4433/classifier-api/v1/groups --cert \
      $puppet_host_cert --key $puppet_host_key --cacert $puppet_ca_cert | jq -rc ".[] | .name, .rule"
   )
   (( ${#lines[@]} > 0 )) || {
      fail "Error getting groups from the classifier api." "Please ensure this is run on a Puppet master"
   }

   for ((i=0; i<${#lines[@]}; i+=2)); do get_nodes "${lines[@]:$i:2}"; done
fi

jq -s 'add' <"$_tmp"
