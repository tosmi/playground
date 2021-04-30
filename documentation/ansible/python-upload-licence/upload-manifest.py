#!/bin/env python
#
# a quick pure python example of uploading a manifest.zip file
# to ansible tower
#
# usage: $0 <tower url> <username> <password> <path to manifest>
#
# example:
#   $0 https://tower.local admin redhat manifest.zip

import requests
import json
import base64
import os
import sys

def usage():
    print( """
    Usage: {:s} <tower URL> <username> <password> <manifest file>
    """.format(sys.argv[0]) )
    exit(1)

def main():
    if len(sys.argv) < 5:
        usage()

    URL      = sys.argv[1]
    USER     = sys.argv[2]
    PASSWORD = sys.argv[3]
    MANIFEST = sys.argv[4]

    config_endpoint = "{:s}/api/v2/config/".format(URL)
    print("Posting to {:s}".format(config_endpoint))

    if not os.path.exists(MANIFEST):
        print("manifest file {:s} not found".format(MANIFEST))
        exit(1)

    files = {'file': open(MANIFEST, 'rb')}

    with open(MANIFEST, 'rb') as m:
        payload = {
            'eula_accepted': True,
            'manifest': base64.b64encode(m.read()).decode()
        }

        r = requests.post(config_endpoint, auth=('admin', 'redhat'), verify=False, json=payload)
        print("Got a '{:d}: {:s}' response".format(r.status_code, r.reason))

if __name__ == "__main__":
    main()
