import os

def write_file_tree_and_contents(start_path, output_file):
    with open(output_file, 'w') as f:
        for dirpath, dirnames, filenames in os.walk(start_path):
            for filename in filenames:
                file_path = os.path.join(dirpath, filename)
                f.write(f"File: {file_path}\n")
                try:
                    with open(file_path, 'r', encoding='utf-8') as file:
                        f.write(file.read())  # Write file contents
                except Exception as e:
                    f.write(f"Could not read file: {str(e)}\n")
                f.write("\n" + "-"*50 + "\n")  # Separator between files

if __name__ == "__main__":
    # Define the path to the directory and the output file name
    directory_to_scan = '.'  # Current directory
    output_file = 'output.txt'  # Output file to save the contents

    write_file_tree_and_contents(directory_to_scan, output_file)
    print(f"File tree and contents have been saved to '{output_file}'.")
