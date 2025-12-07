import opencc
import sys
import argparse
import os


def convert_file(input_path, output_path=None):
    """
    Convert a file from Simplified Chinese to Traditional Chinese (Taiwan standard).
    """
    if output_path is None:
        output_path = input_path

    # s2twp: Simplified Chinese to Traditional Chinese (Taiwan Standard) with phrases
    converter = opencc.OpenCC("s2twp")

    try:
        if not os.path.exists(input_path):
            print(f"Error: Input file not found: {input_path}")
            sys.exit(1)

        with open(input_path, "r", encoding="utf-8") as f:
            content = f.read()

        converted_content = converter.convert(content)

        with open(output_path, "w", encoding="utf-8") as f:
            f.write(converted_content)

        print(f"Successfully converted: {input_path}")

    except Exception as e:
        print(f"Error converting file {input_path}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert Simplified Chinese to Traditional Chinese (Taiwan)."
    )
    parser.add_argument("input_file", help="Path to the input file")
    parser.add_argument(
        "--output",
        help="Path to the output file (optional, defaults to overwriting input)",
        default=None,
    )

    args = parser.parse_args()

    convert_file(args.input_file, args.output)
