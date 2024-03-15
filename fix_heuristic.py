import json
import re
import sys
import subprocess

def parse_error_log(error_log_path):
    try:
        with open(error_log_path, 'r') as file:
            error_message = file.read()
    except FileNotFoundError:
        return None, "Error: File not found."

    # Regular expression patterns to find the failing package and missing module
    package_version_pattern = r"Processing /build/(?P<package_name>[a-zA-Z0-9_-]+)-(?P<version>[0-9.]+)"
    missing_module_pattern = r"ModuleNotFoundError: No module named '([^']+)'"

    # Find failing package and missing module
    package_version_match = re.search(package_version_pattern, error_message)
    missing_module_match = re.search(missing_module_pattern, error_message)

    if package_version_match and missing_module_match:
        package_name = package_version_match.group('package_name')  # The package name
        version = package_version_match.group('version')  # The version
        missing_module = missing_module_match.group(1)  # The missing module
        return package_name, missing_module
    else:
        return None, "Error: Failed to parse error message."

def create_dependencies_json(package_name, missing_module):
    json_content = {package_name: [missing_module]}
    json_filename = f"{package_name}_dependencies.json"
    print(json_content)
    with open(json_filename, 'w') as json_file:
        json.dump(json_content, json_file)
    return json_filename

def merge_dependencies(package_name):
    new_json_filename = f"{package_name}_dependencies.json"
    merged_json_filename = "poetry2nix/overrides/build-systems.json"
    jq_command = [
        'jq', '-s',
        '.[0] as $orig | .[1] as $new | ($new | to_entries[]) as $deps | $orig * (reduce $deps.key as $pkg ({}; .[$pkg] = ($orig[$pkg] + $new[$pkg] | unique)))',
        'poetry2nix/overrides/build-systems.json', new_json_filename
    ]

    try:
        with open(merged_json_filename, 'w') as outfile:
            subprocess.run(jq_command, stdout=outfile, check=True)
        return f"Merged JSON file created: {merged_json_filename}"
    except subprocess.CalledProcessError as e:
        return f"Error during merging: {e}"

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_heuristic.py <error_log_file>")
    else:
        error_log_path = sys.argv[1]
        package_name, missing_module = parse_error_log(error_log_path)
        if package_name and missing_module:
            json_filename = create_dependencies_json(package_name, missing_module)
            print(f"JSON file created: {json_filename}")

            merge_result = merge_dependencies(package_name)
            print(merge_result)
        else:
            print("No action required or error encountered.")
