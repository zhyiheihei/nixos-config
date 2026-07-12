import os

import requests

API_BASE = "https://api.gcore.com/dns/v2"
IP_LOOKUP_URL = "https://api.ipify.org"
TTL = 60

RECORDS = {
    "zhyi.cc": [
        "colocrossing.zhyi.cc",
        "*.colocrossing.zhyi.cc",
    ],
    "zhyi.xin": [
        "zhyi.xin",
        "*.zhyi.xin",
    ],
    "moliy.site": [
        "moliy.site",
        "*.moliy.site",
    ],
}


def get_current_ipv4() -> str:
    response = requests.get(IP_LOOKUP_URL, timeout=10)
    response.raise_for_status()
    return response.text.strip()


def update_record(api_key: str, zone: str, name: str, ipv4: str) -> None:
    response = requests.put(
        f"{API_BASE}/zones/{zone}/{name}/A",
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
    print(f"[OK] {name} -> {ipv4}")


def main() -> None:
    api_key = os.environ.get("GCORE_PERMANENT_API_TOKEN")
    if not api_key:
        raise RuntimeError("GCORE_PERMANENT_API_TOKEN is not set")

    ipv4 = get_current_ipv4()
    for zone, names in RECORDS.items():
        for name in names:
            update_record(api_key, zone, name, ipv4)


if __name__ == "__main__":
    main()
