import os
import re
from ipaddress import IPv4Address

import requests

API_BASE = "https://api.gcore.com/dns/v2"
# The H28K is the remote-site router: its DHCP WAN is dynamic, so point the
# site hostname at the current public IPv4 (IPv4-only; the R5C router's
# home-ddns.zhyi.cc script additionally manages a WG IPv6 record).
ZONE_NAME = "zhyi.xin"
RRSET_NAME = "site"
IP_LOOKUP_URLS = [
    "https://ip.3322.net",
    "http://members.3322.org/dyndns/getip",
    "https://myip.ipip.net",
]
TTL = 120


def get_current_ipv4() -> str:
    errors = []
    session = requests.Session()
    session.trust_env = False
    for url in IP_LOOKUP_URLS:
        try:
            response = session.get(url, timeout=10)
            response.raise_for_status()
            match = re.search(r"(?:\d{1,3}\.){3}\d{1,3}", response.text)
            if not match:
                raise ValueError("response does not contain an IPv4 address")
            return str(IPv4Address(match.group(0)))
        except (requests.RequestException, ValueError) as error:
            errors.append(f"{url}: {error}")
    raise RuntimeError("Unable to determine public IPv4: " + "; ".join(errors))


def update_record(api_key: str, ipv4: str) -> None:
    response = requests.put(
        f"{API_BASE}/zones/{ZONE_NAME}/{RRSET_NAME}/A",
        headers={
            "Authorization": f"APIKey {api_key}",
            "Content-Type": "application/json",
        },
        json={
            "ttl": TTL,
            "resource_records": [
                {
                    "content": [ipv4],
                    "enabled": True,
                }
            ],
        },
        timeout=30,
    )
    response.raise_for_status()
    print(f"[OK] {RRSET_NAME}.{ZONE_NAME} -> {ipv4}")


def main() -> None:
    api_key = os.environ.get("GCORE_PERMANENT_API_TOKEN")
    if not api_key:
        raise RuntimeError("GCORE_PERMANENT_API_TOKEN is not set")
    update_record(api_key, get_current_ipv4())


if __name__ == "__main__":
    main()
