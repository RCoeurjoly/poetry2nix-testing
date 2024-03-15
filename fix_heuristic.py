
import json
import re

def parse_error_and_create_json(error_message):
    # Regular expression patterns to find the failing package and missing module
    failing_package_pattern = r"error: builder for '/nix/store/[^']+-(python3\.\d+)-([^'/]+)-\d"
    missing_module_pattern = r"ModuleNotFoundError: No module named '([^']+)'"

    # Find failing package and missing module
    failing_package_match = re.search(failing_package_pattern, error_message)
    missing_module_match = re.search(missing_module_pattern, error_message)

    if failing_package_match and missing_module_match:
        package_name = failing_package_match.group(2)  # The package name
        missing_module = missing_module_match.group(1)  # The missing module

        # Creating JSON content
        json_content = {
            package_name: [missing_module]
        }

        # Save JSON content to a file
        json_filename = f"{package_name}_dependencies.json"
        with open(json_filename, 'w') as json_file:
            json.dump(json_content, json_file)

        return f"JSON file created: {json_filename}"
    else:
        return "Error: Failed to parse error message."

# Example usage
error_message = """
building '/nix/store/zinl4r0k4dxgp7wm5ih9plkmad2h3g58-zope.interface-6.2.tar.gz.drv'...
building '/nix/store/83dvrqa0ijx7x5bhnh2ak1nyf1zi3wfa-python3.11-zope-interface-6.2.drv'...
building '/nix/store/fnvl24cy47agpn65qnqd03ss6ii7gh6g-python3.11-twisted-23.10.0.drv'...
error: builder for '/nix/store/fnvl24cy47agpn65qnqd03ss6ii7gh6g-python3.11-twisted-23.10.0.drv' failed with exit code 2;
       last 10 log lines:
       >   File "<frozen importlib._bootstrap>", line 1204, in _gcd_import
       >   File "<frozen importlib._bootstrap>", line 1176, in _find_and_load
       >   File "<frozen importlib._bootstrap>", line 1126, in _find_and_load_unlocked
       >   File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
       >   File "<frozen importlib._bootstrap>", line 1204, in _gcd_import
       >   File "<frozen importlib._bootstrap>", line 1176, in _find_and_load
       >   File "<frozen importlib._bootstrap>", line 1140, in _find_and_load_unlocked
       > ModuleNotFoundError: No module named 'hatchling'
       >
       >
       For full logs, run 'nix log /nix/store/fnvl24cy47agpn65qnqd03ss6ii7gh6g-python3.11-twisted-23.10.0.drv'.
error: 1 dependencies of derivation '/nix/store/r1siinavs71c3y7syfmlq1n2kzd393fp-nix-shell-env.drv' failed to build
"""

print(parse_error_and_create_json(error_message))