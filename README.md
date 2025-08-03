# sx
A CLI tool to convert structured data (JSON, YAML, TOML) into Common Lisp / Scheme-style S-expressions.
### **Key Features:**
- **Multi-format support**: JSON, YAML, TOML → Common Lisp or Scheme
- **Streaming processing**: Handle large files efficiently with constant memory usage
- **Format auto-detection**: Automatically detects input format by extension and content
- **Batch processing**: Process multiple files with validation and error reporting
- **Configuration system**: TOML-based config files with sensible defaults
- **Validation mode**: Check file validity without conversion
- **Pipeline profiling**: Performance analysis with timing and memory tracking
- **AST inspection**: View internal data representation for debugging

## Quick Start
```bash
# Convert JSON to Common Lisp S-expressions
echo '{"name": "Alice", "age": 30}' | sx
# Output: ((name . "Alice") (age . 30))

# Convert YAML file to Scheme format
sx --from yaml --to scheme config.yaml
# Output: (("name" "Alice") ("age" 30))

# Validate multiple files
sx --validate *.json *.yaml
# Reports validation status for each file

# Stream large JSON files
sx --streaming large_data.jsonl
# Processes line-by-line with constant memory usage

# Analyze pipeline performance
sx --pipeline-analysis data.json
# Shows timing and memory usage for each stage

# Inspect internal data structure
sx --ast-dump config.yaml
# Displays parsed AST with type information
``` 

## Installation
### Build from Source
```bash
# Install OCaml and dependencies
sudo pacman -S opam # Arch Linux

# Set up OCaml environment
opam init
opam install dune cmdliner yojson yaml alcotest qcheck

# Build sx
git clone https://github.com/tanctl/sx
cd sx
dune build
sudo dune install

# Verify installation
sx --version
```

## Usage
### Basic Conversion
```bash
# Pipe input
echo '{"key": "value"}' | sx

# File input/output
sx input.json output.lisp

# Specify formats explicitly
sx --from yaml --to scheme data.yml
```

### Format Options
**Input formats:**
- `json` - JSON data and JSON Lines
- `yaml` - YAML documents
- `toml` - TOML configuration files
- `auto` - Auto-detect by file extension and content (default)

**Output formats:**
- `common-lisp` - Common Lisp association lists (default)
- `scheme` - Scheme-style nested lists

### Streaming Mode
For large files or continuous processing:
```bash
# Enable streaming (auto-enabled for large files >1MB or JSON arrays >1KB)
sx --streaming large_file.jsonl

# Process JSON Lines format
cat stream.jsonl | sx --streaming

# Custom buffer size
sx --streaming --buffer-size 8192 data.json
```

### Batch Processing & Validation
```bash
# Validate multiple files
sx --validate config/*.toml data/*.json

# Batch convert with validation
mkdir -p converted/ && for file in src/*.yaml; do sx --validate "$file" && sx "$file" > "converted/$(basename "$file" .yaml).lisp"; done

# Stop on first error
sx --validate --fail-fast *.json

# Quiet mode (errors only)
sx --validate --quiet data/
```
 
### Configuration
sx supports TOML configuration files with this search order:
1. `--config <file>` (command line)
2. `./sx.config` (current directory)
3. `~/.sx.config` (home directory)
4. Built-in defaults

**Example configuration** (`./sx.config`):
```toml
# Default output format
default_output = "common-lisp" # or "scheme"

# Pretty print output
pretty_print = true

# Color output
colors = "auto" # "always", "never", "auto"

# Streaming settings
[streaming]
buffer_size = 8192
auto_enable = true
```

### **CLI Options:**
```
USAGE: sx [OPTIONS] [INPUT_FILES...]
OPTIONS:
-f, --from FORMAT Input format (json|yaml|toml|auto)
-t, --to FORMAT Output format (common-lisp|scheme)
OUTPUT_FILE Output file (positional, default: stdout)
-s, --streaming Enable streaming mode
--buffer-size SIZE Streaming buffer size (default: 8192)
--progress Show progress information in streaming mode
--validate Validate files without converting
--dry-run Show what would be processed (alias for --validate)
--fail-fast Stop on first error
-p, --pretty Pretty print output
-c, --compact Compact output on single line
--config FILE Configuration file
--no-config Skip configuration files
--pipeline-analysis Show performance analysis with timing and memory usage
--ast-dump Show parsed AST instead of converting to S-expressions
-q, --quiet Suppress non-error output
-v, --verbose Show detailed processing information
--version Show version information
--help Show this help
```

## Examples
### Basic Data Conversion

**JSON to Common Lisp:**
```bash
$ echo '{"name": "Lua", "age": 4, "active": true}' | sx

((name . "Lua") (age . 4) (active . t))
```

**YAML to Scheme:**
```bash
$ cat config.yaml
name: App
version: 1.2.3
features:
- auth
- logging
- metrics

$ sx --to scheme config.yaml
(("name" "App")
("version" "1.2.3")
("features" (("auth") ("logging") ("metrics"))))
```

**TOML Configuration:**
```bash
$ cat server.toml
host = "localhost"
port = 8080
debug = true

[database]
url = "postgresql://localhost/mydb"
pool_size = 10

$ sx server.toml
((host . "localhost")
(port . 8080)
(debug . t)
(database . ((url . "postgresql://localhost/mydb") (pool_size . 10))))
```

### API Response Processing
```bash
# Get GitHub API data and convert to Lisp
curl -s https://api.github.com/repos/ocaml/dune | sx --pretty

# Multiple API endpoints
for repo in ocaml/dune mirage/mirage ocsigen/lwt; do
curl -s "https://api.github.com/repos/$repo" | \
sx --to scheme > "${repo##*/}-info.lisp"
done

# Process paginated API responses
curl -s "https://api.github.com/repos/ocaml/dune/issues?per_page=100" | \
sx --streaming > issues.lisp
```

### Configuration File Conversion
```bash
# Convert TOML config to Lisp for processing
sx --from toml Cargo.toml cargo-config.lisp

# Convert package.json to Lisp for analysis
sx package.json > package.lisp

# Process Cargo.toml dependencies
sx Cargo.toml | grep -A 20 dependencies

# Convert composer.json
sx --from json --to scheme composer.json
```
  
### Data Pipeline Integration
```bash
# Validate JSON files in CI/CD
find data/ -name "*.json" | xargs sx --validate --fail-fast

# Convert YAML manifests for Lisp-based tools
mkdir -p lisp-configs/ && for file in k8s/*.yaml; do sx --to scheme "$file" > "lisp-configs/$(basename "$file" .yaml).lisp"; done

# Process JSON Lines log files
tail -f access.jsonl | sx --streaming --to scheme | \
while read line; do

# Process each S-expression with Lisp tools
echo "$line" >> processed-logs.lisp
done

# Batch process data files
find data/ -name "*.json" -exec sx --validate {} \; && \
find data/ -name "*.json" -exec sx --streaming {} \; > all-data.lisp

# Pipeline with jq preprocessing
jq -c '.items[]' large-response.json | sx --streaming > items.lisp
```

## Real-World Integration Examples
### 1. Kubernetes Configuration Processing
Convert YAML manifests for Lisp-based deployment tools:
```bash
# Convert Kubernetes manifests to Lisp
sx --to scheme k8s/deployment.yaml > deployment.lisp

# Batch convert all manifests
mkdir -p lisp-configs
for file in k8s/*.yaml; do
sx --to scheme "$file" > "lisp-configs/$(basename "$file" .yaml).lisp"
done

# Validate all manifests first
sx --validate k8s/*.yaml
```
### 2. Configuration Management
Standardize configuration formats across projects:
```bash
# Convert various config formats to unified Lisp format
sx --validate config/
mkdir -p lisp-config/ && for file in config/*.{toml,yaml,json}; do [[ -f "$file" ]] && sx "$file" > "lisp-config/$(basename "$file" | sed 's/\.[^.]*$/.lisp/')"; done

# Create configuration template
cat > template.toml << EOF
app_name = "Application"
environment = "production"
[server]
host = "0.0.0.0"
port = 3000
[database]
type = "postgresql"
host = "db.example.com"
EOF

sx template.toml > config-template.lisp
```
### 3. Development Workflow Integration
Integrate sx into development processes:
```bash
# Pre-commit hook example
#!/bin/bash
# Validate all data files before commit
if ! sx --validate --quiet data/*.json config/*.yaml; then
echo "Configuration validation failed!"
exit 1
fi

# CI/CD validation
sx --validate --fail-fast deployment/*.yaml || exit 1

# Generate Lisp configs for deployment
sx --to scheme deployment/production.yaml > ops/production.lisp
```
### 4. Integration with Other Tools
**With jq (JSON processing):**
```bash
# Combine jq filtering with sx conversion
jq '.results[]' api-response.json | sx --streaming

# Process and convert in pipeline
curl -s api.example.com/data | \
jq '.items[] | select(.active == true)' | \
sx --to scheme
```

**With yq (YAML processing):**
```bash
# Extract specific YAML sections
yq eval '.spec.containers[]' k8s-deployment.yaml | sx --to scheme

# Convert filtered YAML
yq eval 'select(.kind == "Deployment")' manifest.yaml | sx
```

**With find and xargs:**
```bash
# Process all JSON files in directory tree
find . -name "*.json" -print0 | xargs -0 sx --validate

# Convert configuration files
find config/ -name "*.toml" | xargs -I {} sh -c 'sx "$1" > "lisp/$(basename "$1" .toml).lisp"' _ {}
```
 
### 5. Shell Script Integration
```bash
#!/bin/bash
# deployment-converter.sh
set -euo pipefail
INPUT_DIR="$1"
OUTPUT_DIR="$2"

# Validate all input files
echo "Validating configurations..."
if ! sx --validate --quiet "$INPUT_DIR"/*.{json,yaml,toml}; then
echo "Validation failed!" >&2
exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Convert all files
echo "Converting to Lisp format..."
for file in "$INPUT_DIR"/*.{json,yaml,toml}; do
[[ -f "$file" ]] || continue
base=$(basename "$file")
sx --to scheme "$file" > "$OUTPUT_DIR/${base%.*}.lisp"
echo "Converted: $base"
done
echo "Conversion complete!"
```
## Advanced Usage Patterns
### Streaming Large Files
Process large datasets efficiently:
```bash
# Stream large JSON files
sx --streaming --buffer-size 8192 large-dataset.json > output.lisp

# Process multiple large files
for file in data/large-*.json; do
echo "Processing $file..."
sx --streaming "$file" > "processed/$(basename "$file" .json).lisp"
done

# Monitor streaming progress
sx --streaming --verbose large-file.jsonl 2> progress.log
```

### Batch Processing with Error Handling
Handle multiple files with proper error reporting:
```bash
# Validate all files, continue on errors
sx --validate config/*.toml data/*.json 2> validation-errors.log

# Process files, stop on first error
sx --validate --fail-fast important-configs/*.yaml

# Quiet validation for scripting
if sx --validate --quiet deployment/*.json; then
echo "All deployment configs are valid"
mkdir -p processed/ && for file in deployment/*.json; do sx "$file" > "processed/$(basename "$file" .json).lisp"; done
else
echo "Validation failed, check configs"
exit 1
fi
```
  
### Configuration File Management
Use configuration files effectively:
```bash
# Create project-specific config
cat > ./sx.config << EOF
default_output = "scheme"
pretty_print = true
colors = "always"

[streaming]
buffer_size = 8192
auto_enable = true
EOF

# Use config for consistent processing
sx data/*.yaml # Uses ./sx.config automatically

# Override config for specific use case
sx --config production.config deployment.yaml
```

### Error Handling Examples
**Debugging Invalid Files:**
```bash
# Identify problematic files
sx --validate data/*.json 2>&1 | grep "Error"

# Verbose error information
sx --validate --verbose problematic-file.json

# Check specific file in detail
sx --dry-run --verbose config.yaml
```

**Handling Mixed File Types:**
```bash
# Process mixed formats with validation
for file in data/*; do
if sx --validate --quiet "$file"; then
sx "$file" > "output/$(basename "$file").lisp"
else
echo "Skipping invalid file: $file" >&2
fi
done
```

### Performance Optimization Tips
**Optimal Buffer Sizes:**
```bash
# Small files: default buffer (8192)
sx small-configs/*.toml

# Large files: larger buffer
sx --buffer-size 16384 --streaming large-dataset.json

# Very large files: maximum buffer
sx --buffer-size 65536 --streaming huge-export.jsonl
```

**Memory-Efficient Processing:**
```bash
# Force streaming for memory efficiency
sx --streaming medium-file.json

# Process large directories in chunks
find data/ -name "*.json" | head -100 | xargs sx --validate
find data/ -name "*.json" | tail -n +101 | head -100 | xargs sx --validate
```

### Pipeline Performance Analysis
Analyze processing performance with detailed timing and memory tracking:
```bash
# Basic performance analysis
sx --pipeline-analysis data.json
# Output:
# Pipeline Analysis:
# Parse    |  15ms  | 2.1MB
# Generate |   3ms  | 0.2MB  
# Total    |  18ms  | 2.3MB

# Combine with other features
sx --pipeline-analysis --to scheme config.yaml
sx --pipeline-analysis --streaming large-file.jsonl

# Performance analysis with file processing
sx --pipeline-analysis --from yaml deployment.yaml > output.lisp
```

**Use Cases:**
- **Performance optimization**: Identify bottlenecks in parsing vs generation
- **Memory profiling**: Track memory usage for different input types
- **Benchmark comparison**: Compare performance across formats and configurations
- **Production monitoring**: Understand processing characteristics

### AST Structure Inspection
View internal data representation for debugging and understanding:
```bash
# Inspect JSON structure
sx --ast-dump data.json
# Output:
# Assoc
# ├─ "name" -> String("Alice")
# ├─ "age" -> Int(30)
# └─ "settings" -> Assoc
#   ├─ "theme" -> String("dark")
#   └─ "notifications" -> Bool(true)

# Inspect YAML with explicit format
sx --ast-dump --from yaml config.yaml

# Inspect TOML configuration  
sx --ast-dump server.toml

# Debug complex nested structures
sx --ast-dump kubernetes-deployment.yaml
```

**Use Cases:**
- **Data structure debugging**: Understand how complex data is parsed
- **Format validation**: Verify parsing results for different input formats
- **Schema development**: Design validation schemas based on actual structure
- **Educational**: Learn about internal data representation

## Performance
- **Streaming mode**: Constant memory usage for files of any size
- **Format detection**: Fast content-based detection with fallback to extensions
- **Batch processing**: Optimized for processing many files
- **Zero-copy parsing**: Minimal memory allocation during conversion

**Benchmarks** (approximate):
- Small files (<1MB): ~50ms processing time
- Large files (>100MB): Constant ~16MB memory usage in streaming mode
- JSON Lines: ~100K records/second throughput
### Memory Usage
**Small files (<1MB):**
- Memory usage: ~2-5MB (includes OCaml runtime)
- Processing time: ~10-50ms

**Large files (>10MB, streaming enabled):**
- Memory usage: Constant ~16MB regardless of input size
- Buffer size: 4KB-64KB configurable
- Processing rate: ~100K JSON records/second

**Batch processing:**
- Memory per file: Independent processing
- Parallel validation: Uses system thread pool
- Error aggregation: Bounded memory for error collection
### CPU Performance
**Parser performance (relative):**
- JSON: Fastest (using optimized Yojson)
- YAML: Moderate (external library overhead)
- TOML: Good (custom parser, limited features)

**Generator performance:**
- Common Lisp output: Fast (simple association lists)
- Scheme output: Fast (nested list structure)
- Pretty printing: ~20% overhead
## Architecture
sx is built as a modular OCaml application using a functional programming approach with clear separation of concerns. The architecture prioritizes performance, extensibility, and maintainability.
```
┌─────────────────────────────────────────────────────────────┐
│                        CLI Layer                            │
│  (Command parsing, configuration loading, user interface)  │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   Core Processing                           │
│     (Format detection, validation, streaming control)      │
└─────────┬───────────────────────────────┬───────────────────┘
          │                               │
┌─────────▼─────────┐          ┌──────────▼──────────┐
│     Parsers       │          │    Generators       │
│ (JSON/YAML/TOML)  │          │ (Common Lisp/Scheme)│
└───────────────────┘          └─────────────────────┘
          │                               │
┌─────────▼───────────────────────────────▼───────────────────┐
│                  Supporting Systems                         │
│        (Error handling, Config system, Streaming)          │
└─────────────────────────────────────────────────────────────┘
```
### Module Organization
**Core Modules**
**`lib/sx/`** - Core Logic
- `ast.ml` - AST types, S-expression types, and formatting utilities
- `config.ml` - Configuration file parsing and management
- `error.ml` - Error handling and validation reporting
- `position.ml` - Source position tracking for error reporting
- `profiler.ml` - Pipeline performance analysis and timing
- `inspector.ml` - AST inspection and debugging utilities

**`lib/parsers/`** - Input Format Parsers
- `json.ml` - JSON parsing with Yojson integration and streaming support
- `yaml_parser.ml` - YAML parsing with yaml library integration
- `toml.ml` - Simplified TOML parser (custom implementation)
- `detect.ml` - Automatic format detection logic

**`lib/generators/`** - S-expression Generators
- `common_lisp.ml` - Common Lisp association list output
- `scheme.ml` - Scheme-style nested list output

**`lib/cli/`** - Command Line Interface
- `args.ml` - Argument parsing with Cmdliner
- `io.ml` - I/O utilities, streaming detection, and file handling

**`bin/`** - Executable
- `main.ml` - Main application entry point

### Data Flow
```
Input Data
    │
    ▼
┌─────────────────┐
│ Format Detection│  ──┐
└─────────────────┘    │
    │                  │ (Auto mode)
    ▼                  │
┌─────────────────┐    │
│ Content Analysis│ ◄──┘
└─────────────────┘
    │
    ▼
┌─────────────────┐
│   Parser        │ ── JSON/YAML/TOML specific parsing
│  (format-specific)
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  Internal AST   │ ── Unified intermediate representation
└─────────────────┘
    │
    ▼
┌─────────────────┐
│   Generator     │ ── Common Lisp or Scheme output
│ (format-specific)
└─────────────────┘
    │
    ▼
S-expression Output
```

### Design Decisions
**1. Unified AST Approach**
All input formats are parsed into a common intermediate representation defined in `lib/sx/ast.ml`:
```ocaml
type value =
| String of string * position
| Number of float * position
| Bool of bool * position
| Null of position
| Array of value list * position
| Assoc of (string * value) list * position
```

**2. Streaming Architecture**
Streaming is implemented at the parser level with configurable buffer sizes:
```ocaml
type streaming_config = {
auto_threshold : int; (* auto-enable streaming above this size *)
buffer_size : int; (* read buffer size *)
show_progress : bool;
}
```

**Memory Guarantees:**
- Constant memory usage regardless of input size
- Configurable buffer sizes (4KB to 64KB)
- Progress reporting for long-running operations

**3. Error Handling Strategy**
Multi-layered error handling with context preservation:
```ocaml
type error = {
error_type : error_type;
message : string;
position : position option;
filename : string option;
context : string option;
}

type validation_result = {
filename : string;
success : bool;
error : error option;
warning_count : int;
}
```

**Error Categories:**
- **Parse errors**: Syntax issues in input data
- **IO errors**: File system and network issues
- **Validation errors**: Schema or format validation
- **Configuration errors**: Config file and CLI argument issues

**Error Recovery:**
- Fail-fast by default (stops on first error)
- Batch validation mode (collects all errors)
- Detailed position reporting where possible
- Colored output for better UX

**4. Configuration System**
Hierarchical configuration with TOML format:
**Search Order:**
1. Command-line arguments (highest priority)
2. `--config <file>` specified file
3. `./sx.config` (project-level)
4. `~/.sx.config` (user-level)
5. Built-in defaults (lowest priority)

**Configuration Schema:**
```toml
default_output = "common-lisp"
pretty_print = true
colors = "auto"

[streaming]
buffer_size = 8192
auto_enable = true
```  

**5. Format Detection**
Multi-strategy format detection for robust auto-detection:
```ocaml
type detection_strategy =
| Extension_based (* file extension analysis *)
| Content_based (* content signature detection *)
| Hybrid (* both extension and content *)
```

**Detection Logic:**
1. **Extension mapping**: `.json` → JSON, `.yaml`/`.yml` → YAML, `.toml` → TOML
2. **Content analysis**: Parse first few bytes for format signatures
3. **Heuristic parsing**: Attempt parsing with most likely format
4. **Fallback chain**: Try formats in order of likelihood

### I/O Performance
**Streaming I/O:**
- Buffered reads with configurable buffer size
- Write buffering for output
- Progress reporting with minimal overhead

**Batch I/O:**
- Parallel file validation
- Sequential processing (memory efficient)
- Error-first processing (fail-fast optimization)

### Extensibility Points
**Adding New Input Formats**
1. Create parser module in `lib/parsers/`
2. Implement `parse_string` function returning AST
3. Add format detection rules
4. Update CLI argument parsing
5. Add test cases

Example skeleton:
```ocaml
(* lib/parsers/new_format.ml *)
let parse_string ~filename content =
(* Parse content into AST.value *)
...
```

**Adding New Output Formats**
1. Create generator module in `lib/generators/`
2. Implement AST → output string conversion
3. Update CLI argument parsing
4. Add formatting options if needed
5. Add test cases

**Extending Configuration**
1. Add fields to config type in `lib/sx/config.ml`
2. Update TOML parsing logic
3. Add CLI argument mappings
4. Update default values
5. Document new options

### Testing Strategy
The test suite follows a "realistic coverage" approach:
**Unit Tests** (`tests/unit/`):
- Parser correctness for common inputs
- Generator output validation
- Configuration loading
- Error handling paths

**Integration Tests** (`tests/integration/`):
- CLI functionality end-to-end
- Streaming mode validation
- Batch processing workflows
- Auto-detection accuracy

**Property Tests** (`tests/property/`):
- Round-trip parsing (where applicable)
- Basic invariants (valid input → valid output)
- Error handling consistency

**Fixture Tests** (`tests/fixtures/`):
- Real-world file samples
- Performance regression testing
- Edge case validation
### Dependencies
**Core Dependencies:**
- `dune` - Build system
- `cmdliner` - CLI argument parsing
- `yojson` - JSON parsing
- `yaml` - YAML parsing

**Development Dependencies:**
- `alcotest` - Unit testing framework
- `qcheck` - Property-based testing
- Standard OCaml libraries

**Dependency Strategy:**
- Minimize external dependencies
- Use well-maintained, stable libraries
- Custom implementations where appropriate (TOML parser)
- No optional dependencies (all features always available)

### Security Considerations
**Input Validation:**
- All input is validated before processing
- Parser error handling prevents crashes
- File size limits configurable
- Path traversal protection for file operations

**Output Safety:**
- No code execution in generated S-expressions
- Safe string escaping in all output formats
- No shell command injection vectors
- Configuration file parsing is sandboxed

**Resource Limits:**
- Memory usage bounded in streaming mode
- Processing time limits configurable
- File size validation before processing
- DoS protection through resource limiting
## Limitations
sx is designed for common use cases with reasonable trade-offs:
- **TOML support**: Basic syntax only (no advanced TOML features like arrays of tables)
- **YAML support**: Standard YAML features (no custom tags or advanced anchoring)
- **Error recovery**: Stops on first parse error (fail-fast approach)
- **Output formats**: Limited to two S-expression styles (Common Lisp, Scheme)
- **Streaming**: Works best with JSON Lines format; other formats processed sequentially
## Related Writing 
[Transformation Pipelines Across Domains: Patterns in Circuit Compilation and Data Processing](https://tanya.rs/blog/transformation-pipelines.html)
## License
GPL v3 - see LICENSE file for details.