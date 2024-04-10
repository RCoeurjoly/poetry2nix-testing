import json
import re
import sys
import subprocess
import os

def parse_error_log(error_log_path):
    try:
        with open(error_log_path, 'r') as file:
            error_message = file.read()
    except FileNotFoundError:
        return None, "Error: File not found."

    # Regular expression patterns to find the failing package and missing module
    package_version_pattern = r"Processing /build/(?P<package_name>[a-zA-Z0-9_-]+)-(?P<version>[0-9.]+)"
    package_version_pattern2 = r'python3\.\d+-(?P<package_name>[a-zA-Z0-9]+)-(?P<version>\d+\.\d+\.\d+)\.drv'

    missing_module_pattern = r"ModuleNotFoundError: No module named '([^']+)'"

    # Find failing package and missing module
    package_version_match = re.search(package_version_pattern, error_message)
    package_version_match2 = re.search(package_version_pattern2, error_message)
    missing_module_match = re.search(missing_module_pattern, error_message)

    if (package_version_match or package_version_match2) and missing_module_match:
        if package_version_match:
            package_name = package_version_match.group('package_name')  # The package name
            version = package_version_match.group('version')  # The version
        elif package_version_match2:
            package_name = package_version_match2.group('package_name')  # The package name
            version = package_version_match2.group('version')  # The version
        missing_module = missing_module_match.group(1)  # The missing module
        return package_name, version, missing_module
    else:
        return None, None, "Error: Failed to parse error message."

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

def commit_file_in_submodule(file_path: str, commit_message: str, submodule_path: str):
    """
    Commits a specified file in a Git submodule.

    :param file_path: Path to the file to commit, relative to the submodule's root.
    :param commit_message: Commit message for Git.
    :param submodule_path: Path to the submodule's root directory.
    """
    # Save current directory
    current_dir = os.getcwd()

    try:
        # Change directory to the submodule's root
        os.chdir(submodule_path)

        # Add the file to staging
        subprocess.run(['git', 'add', file_path], check=True)

        # Commit the change
        subprocess.run(['git', 'commit', '-m', commit_message, file_path], check=True)

        print(f"Successfully committed {file_path} in submodule at {submodule_path}")

    except subprocess.CalledProcessError as e:
        print(f"An error occurred while trying to commit the file: {e}")

    finally:
        # Change back to the original directory
        os.chdir(current_dir)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_heuristic.py <error_log_file>")
    else:
        error_log_path = sys.argv[1]
        # Modify the script to write to a specific directory, change the './' to your desired path
        # output_dir = "./"  # Change this to your desired output directory path
        package_name, version, missing_module = parse_error_log(error_log_path)
        if package_name and version and missing_module:
            json_filename = create_dependencies_json(package_name, missing_module)
            merge_result = merge_dependencies(package_name)
            commit_file_in_submodule(
                file_path='overrides/build-systems.json',
                commit_message='Commit build-systems.json changes',
                submodule_path='/home/roland/poetry2nix-testing/poetry2nix'
            )
            print(merge_result)
        else:
            print("No action required or error encountered.")
