#!/bin/bash

fail() {
   echo "$@"
   exit 1
}

get_nodes() {
   echo "$1"
   local group="$1"; local rule="$2"

   [[ $group && $rule ]] || fail "Error getting rule. Make sure the node group exists"
   [[ $rule == "null" ]] && echo "nothing"

   # Translate it into something the /nodes enpoint can use
   translated_rule="$(curl -s -X POST --cert $puppet_host_cert --key $puppet_host_key --cacert $puppet_local_cert \
      "https://$puppet_server:4433/classifier-api/v1/rules/translate" -H 'Content-Type: application/json' --data "$rule" | jq -c
 '.query')"

   [[ $translated_rule ]] || fail "Error translating rule"

   # Print the node list
   curl -s --cert $puppet_host_cert --key $puppet_host_key --cacert $puppet_local_cert \
      -G "https://$puppet_server:8081/pdb/query/v4/nodes" --data-urlencode "query=$translated_rule" | jq '.[] | .certname'
}

usage() {
   cat <<EOF
Usage: $0 <group name>
<group name> defaults to all groups if empty
EOF
   exit
}

trap fail ERR
declare -A node_groups

(( $# > 1 )) || [[ $@ =~ --help ]] && usage

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
   mapfile -t lines < <( \
      curl -s https://$puppet_server:4433/classifier-api/v1/groups --cert \
      $puppet_host_cert --key $puppet_host_key --cacert $puppet_ca_cert | jq -c ".[] | select(.name == \"$1\") | .name, .rule"
   )
   get_nodes "${lines[@]}"
else
   :
fi
