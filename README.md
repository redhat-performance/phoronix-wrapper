# Phoronix Test Suite Wrapper

## Description

This wrapper facilitates the automated execution of benchmarks via the Phoronix Test Suite. The Phoronix Test Suite is an open-source benchmarking platform that provides a standardized framework for running reproducible benchmarks across a wide range of system components including CPU, memory, storage, networking, and database workloads.

The wrapper provides:
- Automated Phoronix Test Suite download, installation, and execution.
- Support for multiple sub-tests (stress-ng, redis, cockroach, nginx, sqlite, phpbench, openssl, cassandra, apache-iotdb).
- Automated test option selection and input handling.
- Result collection, processing, and verification.
- CSV and JSON output formats with per-test Pydantic schema validation.
- System configuration metadata capture.
- Integration with test_tools framework.
- Optional Performance Co-Pilot (PCP) integration with per-test openmetrics definitions.

## Command-Line Options

```
Phoronix Options:
  --sub_test <name>: Which phoronix sub-test to run.
      Supported: stress-ng, redis, cockroach, nginx, sqlite, phpbench, openssl, cassandra, apache-iotdb.
      Default is stress-ng.
  --test_index <value>: Test index to run. Default is "Test All Options".
      Selects which specific test variant to execute within the chosen sub-test.

General test_tools options:
  --home_parent <value>: Parent home directory. If not set, defaults to current working directory.
  --host_config <value>: Host configuration name, defaults to current hostname.
  --iterations <value>: Number of times to run the test, defaults to 1.
  --iteration_default <value>: Value to set iterations to, if default is not set.
  --no_pkg_install: Test is not to use dnf/yum/apt or other such tools for package installation.
  --run_user: User that is actually running the test on the test system. Defaults to current user.
  --sys_type: Type of system working with (aws, azure, hostname). Defaults to hostname.
  --sysname: Name of the system running, used in determining config files. Defaults to hostname.
  --test_verification <test_verify_file>: Runs the test verification. Information is in the test_verify file in the tests github.
  --tuned_setting: Used in naming the results directory. For RHEL, defaults to current active tuned profile.
      For non-RHEL systems, defaults to 'none'.
  --use_pcp: Enable Performance Co-Pilot monitoring during test execution.
  --tools_git <value>: Git repo to retrieve the required tools from.
      Default: https://github.com/redhat-performance/test_tools-wrappers
  --usage: Display this usage message.
```

## What the Script Does

The `run_phoronix.sh` script performs the following workflow:

1. **Environment Setup**:
   - Clones the test_tools-wrappers repository if not present (default: ~/test_tools).
   - Sources error codes and general setup utilities.
   - Calls gather_data and general_setup for system configuration.

2. **Package Installation**:
   - Installs required dependencies via package_tool (gcc, graphviz, php-cli, php-xml, bc, etc.).
   - Dependencies are defined in phoronix.json for different OS variants (RHEL, Ubuntu, SLES, Amazon Linux).
   - On Ubuntu, explicitly installs php-cli and php-xml.

3. **Phoronix Test Suite Installation**:
   - Clones Phoronix Test Suite version v10.8.1 from GitHub.
   - Installs the specified sub-test using automated input.
   - Verifies installation by checking the list of installed tests.

4. **Test Input Preparation**:
   - Generates `/tmp/ph_opts` file with test parameters based on the sub-test type.
   - For redis and cockroach tests: provides test_index twice (two selection prompts).
   - For apache-iotdb tests: provides test_index three times.
   - For other tests: provides test_index once.
   - Appends "n" to skip the automatic result upload prompt.

5. **PCP Initialization** (if `--use_pcp` enabled):
   - Creates openmetrics mapping file from per-test metric definitions.
   - Sets up Performance Co-Pilot monitoring.
   - Starts PCP logging in a timestamped directory.

6. **Test Execution**:
   - Runs the Phoronix Test Suite with automated responses from the prepared input file.
   - Executes for the specified number of iterations.
   - Records start and end timestamps for each iteration.
   - Captures PCP snapshots at iteration boundaries.

7. **Result Processing**:
   - Extracts performance metrics from raw Phoronix output using the `reduce_phoronix` utility.
   - Uses test-specific parsing functions to handle different output formats.
   - Generates CSV files with headers and performance data.
   - Creates JSON output for verification.
   - Validates results against per-test Pydantic schemas.

8. **PCP Data Collection** (if enabled):
   - Populates test-specific PCP metrics using dedicated functions (pcp_generic, pcp_redis, pcp_cockroach, pcp_nginx, pcp_sqlite, pcp_phpbench).
   - Records iteration markers for performance correlation.

9. **Output**:
    - Creates timestamped results directory in `/tmp/results_${test_name}_${tuned_setting}_YYYY.MM.DD-HH.MM.SS/`.
    - Creates subdirectory `results_phoronix_${sub_test}/`.
    - Saves all raw output files, processed CSV/JSON, and system metadata.
    - Optionally saves PCP performance data.
    - Archives results to configured storage location.

## Dependencies

Location of underlying workload: https://github.com/phoronix-test-suite/phoronix-test-suite (version v10.8.1).

**General packages required**: gcc, graphviz, git, bc, zip, unzip

**Additional packages by OS variant**:
- RHEL: lksctp-tools-devel, php-cli, php-xml, php-json, perf, perl-FindBin, perl-IPC-Cmd, perl-Time-Piece, pcp-zeroconf, pcp-pmda-openmetrics, pcp-pmda-denki.
- Ubuntu: python3, php-cli, php-xml, php-json, php8-zip, pcp-zeroconf.
- SLES: lksctp-tools-devel, php-cli, php-xml, php-json, perf, pcp, pcp-conf, pcp-system-tools.
- Amazon Linux: php-cli, php-xml.

To run:
```bash
git clone https://github.com/redhat-performance/phoronix-wrapper
cd phoronix-wrapper/phoronix
./run_phoronix.sh
```

The script will automatically install the Phoronix Test Suite and required dependencies.

## Supported Sub-Tests

The wrapper supports the following Phoronix sub-tests, each with dedicated result parsing, schema validation, and PCP metric definitions:

### stress-ng
System stress testing workload generator that loads and stresses kernel interfaces. Measures performance across 58 benchmark types including CPU, memory, cryptography, scheduling, and I/O operations. Results report Average performance and Deviation for each test type.

### redis
Redis in-memory database performance testing. Measures throughput for GET, SET, LPOP, and SADD operations across varying numbers of parallel connections.

### cockroach
CockroachDB distributed SQL database performance testing. Measures read operation throughput with varying concurrency levels. Reports workload type, concurrency, average performance, and deviation.

### nginx
Nginx web server performance testing. Measures requests per second (RPS) across varying numbers of concurrent connections.

### sqlite
SQLite embedded database performance testing. Measures throughput across varying thread counts.

### phpbench
PHP benchmark suite measuring PHP execution performance. Reports average score and deviation.

### openssl
OpenSSL cryptographic operation performance testing. Measures throughput in bytes per second for algorithms including SHA256, SHA512, RSA4096, ChaCha20, AES-128-GCM, AES-256-GCM, and ChaCha20-Poly1305.

### cassandra
Apache Cassandra NoSQL database performance testing. Uses generic three-field reduction (test, average, deviation). Runs without additional test input options.

### apache-iotdb
Apache IoTDB time-series database performance testing. Measures performance across varying device counts, batch sizes, sensor counts, and client numbers. Reports points per second and latency.

## Output Files

The results directory contains:

- **results_${sub_test}.csv**: CSV file with test-specific performance metrics
- **results_schema_${sub_test}.json**: JSON validation output
- **results_${test_name}_${tuned_setting}_iterations_${N}.out**: Raw output from each iteration
- **/tmp/ph_opts**: Generated test input parameters file
- **meta_data*.yml**: System metadata (CPU info, memory, kernel version)
- **PCP data** (if --use_pcp option used): Performance Co-Pilot monitoring data in timestamped directory


## Examples

### Basic run with defaults (stress-ng)
```bash
./run_phoronix.sh
```
This runs with:
- stress-ng sub-test
- "Test All Options" test index
- 1 iteration
- Automatic package installation

### Run a specific sub-test
```bash
./run_phoronix.sh --sub_test redis
```
Runs the Redis benchmark instead of the default stress-ng.

### Run with a specific test index
```bash
./run_phoronix.sh --sub_test openssl --test_index 1
```
Runs a specific OpenSSL test variant instead of all options.

### Run multiple iterations
```bash
./run_phoronix.sh --iterations 3
```
Runs the benchmark 3 times to check consistency.

### Run with PCP monitoring
```bash
./run_phoronix.sh --use_pcp
```
Collects Performance Co-Pilot data during the run.

### Skip package installation
```bash
./run_phoronix.sh --no_pkg_install
```
Runs without attempting to install packages (useful when dependencies are pre-installed).

### Combination example
```bash
./run_phoronix.sh --sub_test nginx --iterations 5 --use_pcp --tuned_setting throughput-performance
```
Runs the Nginx benchmark 5 times with PCP monitoring and a custom tuned setting label.

## How Result Processing Works

The `reduce_phoronix` utility transforms raw Phoronix Test Suite output into structured CSV format using test-specific parsing functions:

1. **reduce_generic()**: Used by stress-ng, sqlite, nginx, openssl. Extracts Test, Average, and Deviation fields from three-field output lines.

2. **reduce_redis()**: Parses parallel connection counts from single-line output and groups results by connection level.

3. **reduce_cockroach()**: Extracts multiple fields per line including workload, concurrency, and average metrics.

4. **reduce_apache-iotdb()**: Parses device_count, batch_size, sensor_count, client_number, points_per_second, and latency.

5. **reduce_phpbench()**: Extracts two-field output (average and deviation).

After CSV generation:
- Non-ASCII characters (ANSI color codes) are stripped.
- CSV is converted to JSON using csv_to_json from test_tools.
- JSON is validated against the corresponding Pydantic schema using verify_results.

## Return Codes

The script uses standardized error codes from test_tools error_codes:
- **0**: Success
- **101**: Git clone failure (test_tools or Phoronix Test Suite)
- **E_GENERAL**: General execution errors (package installation failures, test execution failures, validation failures).
- **E_USAGE**: Invalid usage/arguments

Exit codes indicate specific failure points for automated testing workflows.

## Notes

### Phoronix Test Suite Version
- The wrapper uses Phoronix Test Suite version v10.8.1 (pinned for reproducibility).
- The suite is cloned fresh on each run to ensure a clean state.

### PHP Requirement
- The Phoronix Test Suite requires PHP to run. The wrapper automatically installs php-cli and php-xml.
- On Ubuntu, these packages are explicitly installed after general package setup.

### Test Input Handling
- Different sub-tests require different numbers of input selections. The wrapper handles this automatically by generating the correct number of responses in the `/tmp/ph_opts` file.
- The "n" response at the end prevents automatic result upload to OpenBenchmarking.org.

### PCP Integration
- Each sub-test has a dedicated openmetrics definition file (`openmetrics_phoronix_${sub_test}.txt`) that defines the metrics collected.
- PCP data is stored in timestamped directories under `/tmp/pcp_YYYY.MM.DD-HH.MM.SS/`.
- Test-specific PCP functions populate metrics appropriate to each benchmark type.

### Schema Validation
- Each sub-test has a corresponding Pydantic schema (`results_schema_${sub_test}.py`) that validates the structure and types of output data.
- Schemas enforce value constraints (e.g., positive values for performance metrics) and valid enum values for test names and algorithm identifiers.

### Performance Tips
- Run multiple iterations to verify consistency.
- Ensure system is idle (no other workloads) for best results.
- Consider the active tuned profile on RHEL systems.
- Use `--use_pcp` to collect detailed performance counters for analysis.

### Troubleshooting
- If Phoronix Test Suite fails to install, verify that PHP packages are installed.
- If a sub-test fails to install, check network connectivity (tests are downloaded from OpenBenchmarking.org).
- If result validation fails, check the raw output files for unexpected format changes.
- Verify the test appears in `phoronix-test-suite list-installed-tests` before running.
