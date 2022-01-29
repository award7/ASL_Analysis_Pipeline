def create_vols(host_container_mapping: dict) -> dict:
    vols = {}
    for key, val in host_container_mapping.items():
        vols[key] = {
            'bind': val,
            'mode': 'rw'
        }

    return vols
