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
    original_json_filename = "poetry2nix/overrides/build-systems.json"
    temp_merged_json_filename = "temp_merged_build_systems.json"
    jq_command = [
        'jq', '-s',
        '.[0] as $orig | .[1] as $new | ($new | to_entries[]) as $deps | $orig * (reduce $deps.key as $pkg ({}; .[$pkg] = ($orig[$pkg] + $new[$pkg] | unique)))',
        original_json_filename, new_json_filename
    ]

    try:
        result = subprocess.run(jq_command, capture_output=True, text=True, check=True)
        if result.stdout:
            # Write to a temporary file first
            with open(temp_merged_json_filename, 'w') as temp_file:
                temp_file.write(result.stdout)

            # Replace the original file only if merge was successful and output is not empty
            os.replace(temp_merged_json_filename, original_json_filename)
            return f"Merged JSON file created: {original_json_filename}"
        else:
            return "Error: Merge resulted in an empty output."
    except subprocess.CalledProcessError as e:
        return f"Error during merging: {e}"
