#!/usr/bin/env python3
"""Configure the knowledge-chain Syncthing folder across the three nodes.

Uses the official Syncthing REST API. Run this on each host after the
syncthing service is active; it reads the API key from the local config.xml.

Examples:
  syncthing-setup.py --action setup
  syncthing-setup.py --action status
  syncthing-setup.py --action remove
"""

import argparse
import json
import re
import sys
import urllib.error
import urllib.request

CONFIG_PATH = "/var/lib/syncthing/config.xml"
API_BASE = "http://127.0.0.1:13834"

DEVICES = {
    "ml-2700": "OFHULYP-EHZTYED-ZJKMBJ6-YNC3SSO-GHQD33A-IF4B6QI-IGLCDTF-VZFHJAH",
    "opi5p": "6OVUWPX-LFALVDJ-BMNP24B-LAQQSTJ-BJWPIN4-3TA6GFC-NGAD22X-BRK5HQZ",
    "colocrossing": "N5O6F67-DQRWGKH-LMAOLVW-VJN53EP-MGLEXJ2-AMXHLWE-KHO4XW6-4NR64QP",
}

PATHS = {
    "ml-2700": "/home/zhyi/Documents/Notes",
    "opi5p": "/mnt/storage/media/Notes",
    "colocrossing": "/nix/persistent/media/Notes",
}


def api_key():
    text = open(CONFIG_PATH, encoding="utf-8").read()
    match = re.search(r"<apikey>([^<]+)</apikey>", text)
    if not match:
        sys.exit("cannot find apikey in " + CONFIG_PATH)
    return match.group(1)


def self_id():
    text = open(CONFIG_PATH, encoding="utf-8").read()
    match = re.search(r'<device id="([^"]+)"', text)
    if not match:
        sys.exit("cannot find self device id in " + CONFIG_PATH)
    return match.group(1)


def request(method, path, data=None):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        API_BASE + path,
        method=method,
        headers={"X-API-Key": api_key(), "Content-Type": "application/json"},
        data=body,
    )
    try:
        with urllib.request.urlopen(req) as resp:
            payload = resp.read()
            return json.loads(payload) if payload else None
    except urllib.error.HTTPError as exc:
        print("error", method, path, exc.code, exc.read().decode()[:300])
        return None


def device_names():
    devices = request("GET", "/rest/config/devices") or []
    return [d.get("name") for d in devices]


def folder_ids():
    folders = request("GET", "/rest/config/folders") or []
    return [f.get("id") for f in folders]


def setup():
    self = self_id()
    if self not in DEVICES.values():
        sys.exit("unknown Syncthing device id: " + self)
    host = next(name for name, ident in DEVICES.items() if ident == self)
    peers = [ident for name, ident in DEVICES.items() if name != host]

    existing = device_names()
    for ident in peers:
        if ident not in existing:
            peer_name = next(name for name, value in DEVICES.items() if value == ident)
            request(
                "POST",
                "/rest/config/devices",
                {"deviceID": ident, "name": peer_name, "addresses": ["dynamic"]},
            )

    if "notes" not in folder_ids():
        request(
            "POST",
            "/rest/config/folders",
            {
                "id": "notes",
                "label": "Notes",
                "path": PATHS[host],
                "type": "sendreceive",
                "devices": [{"deviceID": ident} for ident in [self] + peers],
                "rescanIntervalS": 300,
            },
        )

    print("setup done on", host)
    print("devices:", device_names())
    print("folders:", folder_ids())


def remove():
    self = self_id()
    peers = [ident for ident in DEVICES.values() if ident != self]
    for ident in peers:
        request("DELETE", "/rest/config/devices/" + ident)
    request("DELETE", "/rest/config/folders/notes")
    print("remove done; devices:", device_names(), "folders:", folder_ids())


def status():
    self = self_id()
    host = next((name for name, ident in DEVICES.items() if ident == self), "unknown")
    state = request("GET", "/rest/db/status?folder=notes")
    if state:
        print(
            host,
            {
                key: state.get(key)
                for key in ("state", "globalBytes", "localBytes", "needBytes", "errors")
            },
        )
    else:
        print(host, "notes folder status unavailable")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--action", choices=["setup", "remove", "status"], default="setup")
    args = parser.parse_args()
    {"setup": setup, "remove": remove, "status": status}[args.action]()


if __name__ == "__main__":
    main()
