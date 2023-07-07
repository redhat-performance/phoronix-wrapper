Automation wrapper for stress-ng

Description: The stress-ng tool measures the system’s capability to maintain a good level of
             efficiency under unfavorable conditions. The stress-ng tool is a stress workload
             generator to load and stress all kernel interfaces. It includes a wide range of
             stress mechanisms known as stressors. Stress testing makes a machine work hard
             and trip hardware issues such as thermal overruns and operating system bugs that
             occur when a system is being overworked.  in double precision (64 bits) arithmetic
             on distributed-memory computers.  It can thus be regarded as a portable as well
             as freely available implementation of the High Performance Computing Linpack
             Benchmark.
             For more information see:
                https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/8/html/optimizing_rhel_8_for_real_time_for_low_latency_operation/assembly_stress-testing-real-time-systems-with-stress-ng_optimizing-rhel8-for-real-time-for-low-latency-operation
                https://openbenchmarking.org/test/pts/stress-ng-1.2.2
  
Location of underlying workload: https://github.com/phoronix-test-suite/phoronix-test-suite

Packages required: gcc,graphviz,python3,lksctp-tools-devel,php-cli,php-xml,php-json,bc,perf

To run:
[root@hawkeye ~]# git clone https://github.com/redhat-performance/autohpl-wrapper
[root@hawkeye ~]# autohpl-wrapper/auto_hpl/build_run_hpl.sh

The script will set the sizings based on the hardware it is being run.
```
Options
  --test_index: test index to run.  Default is Test All Options
  --tools_git: Location to pick up the required tools git, default
    https://github.com/redhat-performance/test_tools-wrappers
General options
  --home_parent <value>: Our parent home directory.  If not set, defaults to current working directory.
  --host_config <value>: default is the current host name.
  --iterations <value>: Number of times to run the test, defaults to 1.
  --pbench: use pbench-user-benchmark and place information into pbench, defaults to do not use.
  --pbench_user <value>: user who started everything. Defaults to the current user.
  --pbench_copy: Copy the pbench data, not move it.
  --pbench_stats: What stats to gather. Defaults to all stats.
  --run_label: the label to associate with the pbench run. No default setting.
  --run_user: user that is actually running the test on the test system. Defaults to user running wrapper.
  --sys_type: Type of system working with, aws, azure, hostname.  Defaults to hostname.
  --sysname: name of the system running, used in determing config files.  Defaults to hostname.
  --tuned_setting: used in naming the tar file, default for RHEL is the current active tuned.  For non
    RHEL systems, default is none.
  --usage: this usage message.
```

Note: The script does not install pbench for you.  You need to do that manually.
