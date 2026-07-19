import json
import os
from decimal import Decimal

from dcim.models import Device, DeviceRole, DeviceType, Interface, Manufacturer, Platform, Site
from django.contrib.contenttypes.models import ContentType
from django.db import transaction
from extras.models import Tag
from ipam.models import IPAddress


MARKER = "Managed by Nix (netbox-nix-sync)."


def update_managed(obj, values):
    description = getattr(obj, "description", "") or ""
    if description and MARKER not in description:
        return False

    changed = False
    for key, value in values.items():
        if getattr(obj, key) != value:
            setattr(obj, key, value)
            changed = True
    if changed:
        obj.full_clean()
        obj.save()
    return True


def get_named(model, lookup, defaults):
    obj, created = model.objects.get_or_create(**lookup, defaults=defaults)
    if not created:
        update_managed(obj, defaults)
    return obj


def sync_site(data):
    defaults = {
        "name": data["name"],
        "status": "active",
        "description": MARKER,
        "latitude": Decimal(data["latitude"]),
        "longitude": Decimal(data["longitude"]),
    }
    return get_named(Site, {"slug": data["slug"]}, defaults)


def sync_role(name):
    colors = {
        "client": "4caf50",
        "nix-builder": "ff9800",
        "server": "2196f3",
        "node": "9e9e9e",
    }
    return get_named(
        DeviceRole,
        {"slug": name},
        {
            "name": name.replace("-", " ").title(),
            "color": colors[name],
            "description": MARKER,
        },
    )


def sync_tag(name):
    return get_named(
        Tag,
        {"slug": name},
        {
            "name": name,
            "color": "607d8b",
            "description": MARKER,
        },
    )


def sync_device_type(system):
    manufacturer = get_named(
        Manufacturer,
        {"slug": "nixos"},
        {"name": "NixOS", "description": MARKER},
    )
    platform = get_named(
        Platform,
        {"slug": "nixos"},
        {"name": "NixOS", "description": MARKER},
    )
    device_type = get_named(
        DeviceType,
        {"slug": system},
        {
            "manufacturer": manufacturer,
            "model": system,
            "description": MARKER,
        },
    )
    return device_type, platform


def sync_ip(interface, data):
    address = data["address"]
    ip = IPAddress.objects.filter(address=address).first()
    if ip is None:
        ip = IPAddress(address=address)
    elif MARKER not in (ip.description or ""):
        print(f"skip ip {address}: existing object is not Nix-managed")
        return None

    ip.status = "active"
    ip.assigned_object = interface
    ip.dns_name = data.get("dns_name") or ""
    ip.description = f"{MARKER} {data['description']}"
    ip.full_clean()
    ip.save()
    return ip


def sync_device(data):
    existing = Device.objects.filter(name=data["name"]).first()
    if existing is not None and MARKER not in (existing.description or ""):
        print(f"skip device {data['name']}: existing object is not Nix-managed")
        return False

    site = sync_site(data["site"])
    role = sync_role(data["role"])
    device_type, platform = sync_device_type(data["system"])
    comments = "\n".join(
        [
            MARKER,
            f"Source: hosts/{data['name']}/host.nix",
            f"Hostname: {data['hostname']}",
            f"Host index: {data['index']}",
            f"CPU threads: {data['cpu_threads']}",
        ]
    )
    values = {
        "site": site,
        "role": role,
        "device_type": device_type,
        "platform": platform,
        "status": "active",
        "description": MARKER,
        "comments": comments,
    }
    if existing is None:
        device = Device(name=data["name"], **values)
        device.full_clean()
        device.save()
    else:
        device = existing
        update_managed(device, values)

    for tag_name in data["tags"]:
        device.tags.add(sync_tag(tag_name))

    primary4 = None
    primary6 = None
    seen_addresses = set()
    for interface_data in data["interfaces"]:
        interface, created = Interface.objects.get_or_create(
            device=device,
            name=interface_data["name"],
            defaults={
                "type": "virtual",
                "enabled": True,
                "description": f"{MARKER} {interface_data['description']}",
            },
        )
        if not created:
            managed = update_managed(
                interface,
                {
                    "type": "virtual",
                    "enabled": True,
                    "description": f"{MARKER} {interface_data['description']}",
                },
            )
            if not managed:
                print(
                    f"skip interface {data['name']}:{interface_data['name']}: "
                    "existing object is not Nix-managed"
                )
                continue
        for address_data in interface_data["addresses"]:
            if address_data["address"] in seen_addresses:
                continue
            seen_addresses.add(address_data["address"])
            ip = sync_ip(interface, address_data)
            if ip is None:
                continue
            if ip.address.version == 4 and primary4 is None:
                primary4 = ip
            if ip.address.version == 6 and primary6 is None:
                primary6 = ip

    if device.primary_ip4 != primary4 or device.primary_ip6 != primary6:
        device.primary_ip4 = primary4
        device.primary_ip6 = primary6
        device.full_clean()
        device.save()
    return True


def delete_stale_devices(active_names):
    stale_devices = list(
        Device.objects.filter(description__contains=MARKER).exclude(name__in=active_names)
    )
    if not stale_devices:
        return

    interface_type = ContentType.objects.get_for_model(Interface)
    stale_interface_ids = Interface.objects.filter(device__in=stale_devices).values_list(
        "id", flat=True
    )
    stale_ips = IPAddress.objects.filter(
        description__contains=MARKER,
        assigned_object_type=interface_type,
        assigned_object_id__in=stale_interface_ids,
    )
    for ip in stale_ips:
        ip.delete()
    for device in stale_devices:
        print(f"delete stale Nix-managed device {device.name}")
        device.delete()


def delete_unused_inventory_objects():
    managed_devices = list(Device.objects.filter(description__contains=MARKER))
    used_site_ids = {device.site_id for device in managed_devices if device.site_id}
    used_role_ids = {device.role_id for device in managed_devices if device.role_id}
    used_device_type_ids = {
        device.device_type_id for device in managed_devices if device.device_type_id
    }
    used_tag_ids = set()
    for device in managed_devices:
        used_tag_ids.update(device.tags.values_list("id", flat=True))

    managed_objects = (
        (Site, used_site_ids),
        (DeviceRole, used_role_ids),
        (DeviceType, used_device_type_ids),
        (Tag, used_tag_ids),
    )
    for model, used_ids in managed_objects:
        for obj in model.objects.filter(description__contains=MARKER).exclude(
            id__in=used_ids
        ):
            obj.delete()


def main():
    with open(os.environ["NETBOX_NIX_INVENTORY"], encoding="utf-8") as inventory_file:
        inventory = json.load(inventory_file)

    synced = 0
    with transaction.atomic():
        for device in inventory:
            if sync_device(device):
                synced += 1
        delete_stale_devices({device["name"] for device in inventory})
        delete_unused_inventory_objects()
    print(f"netbox-nix-sync: synced {synced}/{len(inventory)} devices")


main()
