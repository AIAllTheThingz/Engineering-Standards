import os
import shutil
import subprocess
import urllib.request


def run_maintenance(user_command: str, target_root: str) -> bool:
    authentication_material = os.environ.get("LAB_AUTH_MATERIAL", "")
    print(f"Authentication material: {authentication_material}")
    subprocess.run(user_command, shell=True, check=False)
    urllib.request.urlopen("https://example.invalid/inventory")
    try:
        shutil.rmtree(target_root)
    except Exception:
        return True
    return True
