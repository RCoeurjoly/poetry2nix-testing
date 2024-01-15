import numpy as np

# Function to read and process the plot data file
def read_plot_data(file_path):
    data = []
    with open(file_path, 'r') as file:
        next(file)  # Skip the header line
        for line in file:
            parts = line.split()
            # Expected format: Project DownloadCount ErrorProbability
            project = parts[0]
            download_count = int(parts[1])
            error_probability = int(parts[2])
            data.append((project, download_count, error_probability))
    return data

# Read the plot data from the file
plot_data_file_path = 'plot_data.dat'  # Replace with the actual file path
plot_data = read_plot_data(plot_data_file_path)

# Sort the data by download count
sorted_data = sorted(plot_data, key=lambda x: x[1], reverse=True)

# Determine the number of packages per slot
total_packages = len(sorted_data)
packages_per_slot = total_packages // 100

# Calculate the average error probability for each slot
slot_error_probabilities = []
for i in range(0, total_packages, packages_per_slot):
    slot_data = sorted_data[i:i + packages_per_slot]
    avg_error_probability = np.mean([item[2] for item in slot_data])
    slot_error_probabilities.append(avg_error_probability)

# Write the slot error probabilities to a file
slot_error_probabilities_file_path = 'slot_error_probabilities.dat'  # Replace with desired file path
with open(slot_error_probabilities_file_path, 'w') as file:
    file.write("# Slot ErrorProbability\n")
    for i, error_probability in enumerate(slot_error_probabilities):
        file.write(f"{i+1} {error_probability}\n")
