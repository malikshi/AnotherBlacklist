#!/bin/bash

# A script to convert various domain list formats to AdGuard Home filter syntax.

# --- Usage Information ---
function show_usage {
    echo "Usage: $0 [-w | -b] [-o <output_file>] <input_file>"
    echo
    echo "Converts a domain list into AdGuard Home filter format."
    echo
    echo "Modes:"
    echo "  -w, --whitelist      Converts plain domains and keyword/regex rules to WHITELIST format."
    echo "  -b, --blocklist      Converts plain domains and keyword/regex rules to BLOCKLIST format. [DEFAULT]"
    echo
    echo "Options:"
    echo "  -o, --output <file>  Write the result to a file instead of standard output."
    echo "  -h, --help           Display this help message."
    echo
    echo "Special Prefixes (always converted to specific block/white rules):"
    echo "  'full:domain.com'        -> domain.com         (Exact domain block)"
    echo "  'keyword:word'           -> /word/ or @@/word/ (Regex keyword, follows mode)"
    echo "  'regex:expression'       -> /expression/ or @@/expression/ (Regex, follows mode)"
    echo "  'regex-white:expression' -> @@/expression/       (Regex whitelist/exception, ignores mode)"
    exit 1
}

# --- Argument Parsing ---
MODE="block" # Default to blocklist mode
INPUT_FILE=""
OUTPUT_FILE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -w|--whitelist) MODE="white"; shift ;;
        -b|--blocklist) MODE="block"; shift ;;
        -o|--output)
            if [ -n "$2" ]; then
                OUTPUT_FILE="$2"
                shift 2
            else
                echo "Error: Argument for $1 is missing" >&2
                exit 1
            fi
            ;;
        -h|--help) show_usage ;;
        -*) echo "Unknown option: $1" >&2; show_usage ;;
        *)
            if [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
                shift
            else
                echo "Error: Multiple input files specified." >&2
                show_usage
            fi
            ;;
    esac
done

# --- Validation ---
if [ -z "$INPUT_FILE" ]; then
    echo "Error: No input file specified." >&2
    show_usage
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found." >&2
    exit 1
fi

# --- Main Processing Logic ---
function process_file {
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Preserve full-line comments and skip empty/whitespace-only lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || ! [[ "$line" =~ [^[:space:]] ]]; then
            echo "$line"
            continue
        fi

        # Extract only the first column of text from the line.
        # This correctly handles descriptions with or without a '#'.
        rule_part=$(echo "$line" | awk '{print $1}')

        # Handle prefixed rules first
        if [[ "$rule_part" == full:* ]]; then
            domain=${rule_part#full:}
            echo "$domain"
        elif [[ "$rule_part" == keyword:* || "$rule_part" == regex:* ]]; then
            # Determine the content of the regex
            if [[ "$rule_part" == keyword:* ]]; then content=${rule_part#keyword:}; else content=${rule_part#regex:}; fi

            # **FIXED LOGIC**: Check the mode to decide whether to add the '@@' whitelist prefix
            if [ "$MODE" == "white" ]; then
                echo "@@/$content/"
            else
                echo "/$content/"
            fi
        elif [[ "$rule_part" == regex-white:* ]]; then
            content=${rule_part#regex-white:}
            echo "@@/$content/"
        else
            # Handle plain domains based on the selected mode
            if [ "$MODE" == "white" ]; then
                echo "@@||$rule_part^"
            else # "block" mode
                echo "||$rule_part^"
            fi
        fi
    done < "$INPUT_FILE"
}

# --- Output Handling ---
if [ -n "$OUTPUT_FILE" ]; then
    process_file > "$OUTPUT_FILE"
    echo "Conversion complete. Output written to '$OUTPUT_FILE'."
else
    process_file
fi