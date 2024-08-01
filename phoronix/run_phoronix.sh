#!/bin/bash
arguments="$@"

test_name="phoronix"
GIT_VERSION="v10.8.1"
curdir=`pwd`
if [[ $0 == "./"* ]]; then
        chars=`echo $0 | awk -v RS='/' 'END{print NR-1}'`
        if [[ $chars == 1 ]]; then
                run_dir=`pwd`
        else
                run_dir=`echo $0 | cut -d'/' -f 1-${chars} | cut -d'.' -f2-`
                run_dir="${curdir}${run_dir}"
        fi
elif [[ $0 != "/"* ]]; then
        dir=`echo $0 | rev | cut -d'/' -f2- | rev`
        run_dir="${curdir}/${dir}"
else
        chars=`echo $0 | awk -v RS='/' 'END{print NR-1}'`
        run_dir=`echo $0 | cut -d'/' -f 1-${chars}`
        if [[ $run_dir != "/"* ]]; then
                run_dir=${curdir}/${run_dir}
        fi
fi


if [ ! -f "/tmp/${test_name}.out" ]; then
        command="${0} $@"
        echo $command
        $command &> /tmp/${test_name}.out
        rtc=$?
        if [[ -f /tmp/${test_name}.out ]]; then
                cat /tmp/${test_name}.out
                rm /tmp/${test_name}.out
        fi
        exit $rtc
fi

tools_git=https://github.com/redhat-performance/test_tools-wrappers

usage()
{
        echo "Usage:"
        echo "  --test_index: test index to run.  Default is $test_index"
        echo "  --tools_git: Location to pick up the required tools git, default"
        echo "    https://github.com/redhat-performance/test_tools-wrappers"
        echo "  --usage: this usage message"
        echo "  -t: test to run"
        source test_tools/general_setup --usage
}

error_out()
{
        echo $1
        exit $2

}

#
# Clone the repo that contains the common code and tools
#
found=0
show_usage=0
for arg in "$@"; do
	if [ $found -eq 1 ]; then
		tools_git=$arg
		break;
	fi
	if [[ $arg == "--tools_git" ]]; then
		found=1
	fi
	if [[ $arg == "--usage" ]]; then
		usage $0
	fi
done

#
# Check to see if the test tools directory exists.  If it does, we do not need to
# clone the repo.
#
if [ ! -d "test_tools" ]; then
        git clone $tools_git
        if [ $? -ne 0 ]; then
                echo pulling git $tools_git failed.
                exit
        fi
fi

if [ $show_usage -eq 1 ]; then
        usage $0
fi


# Variables set by general setup.
#
# TOOLS_BIN: points to the tool directory
# to_home_root: home directory
# to_configuration: configuration information
# to_times_to_run: number of times to run the test
# to_pbench: Run the test via pbench
# to_puser: User running pbench
# to_run_label: Label for the run
# to_user: User on the test system running the test
# to_sys_type: for results info, basically aws, azure or local
# to_sysname: name of the system
# to_tuned_setting: tuned setting
#
${curdir}/test_tools/gather_data ${curdir}
source test_tools/general_setup "$@"
test = "none"

test_tools/package_tool --update
test_tools/package_tool --packages php73-cli.x86_64,php73-common.x86_64,php73-xml.x86_64
if [[ $? != "0" ]]; then
        #
        # Check to see if we need to remove the old php
        #
        test_tools/package_tool --is_installed php-cli.x86_64
        if [ $? -eq 0 ]; then
                packages="php-cli.x86_64 php-common.x86_64 php-xml.x86_64"
                #
                # Remove and add the proper php
                #
                test_tools/package_tool --remove_packages $packages
                if [ $? -ne 0 ]; then
                        error_out "Failed to remove $packages" 1
                fi
        fi
        test_tools/package_tool --packages php73-cli.x86_64,php73-common.x86_64,php73-xml.x86_64
        if [ $? -ne 0 ]; then
                #
                # Just to be difficult Amazon 2 uses even different packages.
                #
                test_tools/package_tool --packages git,php-cli,php-xml,php-json
                if [ $? -ne 0 ]; then
                        error_out "Failed to install $packages" 1
                fi
        fi
fi


ARGUMENT_LIST=(
  "test_index"
	"sub_test"
)

NO_ARGUMENTS=(
	"usage"
)

# read arguments
opts=$(getopt \
    --longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --longoptions "$(printf "%s," "${NO_ARGUMENTS[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

if [ $? -ne 0 ]; then
    echo "Error with option parsing"
    exit 1
fi

eval set --$opts

while true; do
    case "$1" in
        --test_index)
            test_index=$2
            shift 2
            ;;
        --sub_test)
            test=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit
            ;;
        --usage)
            usage
            exit
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ $test == "none" ]]; then
        echo You must designate a test
        usage $0
fi


if [ $to_pbench -eq 1 ]; then
        source ~/.bashrc
        move_back=0
        move_this=`ls /var/lib/pbench-agent/tools-*-default/*/perf`
        if [ $? -eq 0 ]; then
                move_back=1
                mv $move_this /tmp/perf
        fi
        echo $TOOLS_BIN/execute_via_pbench --cmd_executing "$0" $arguments --test ${test_name}_${test} --spacing 11 --pbench_stats $to_pstats
        $TOOLS_BIN/execute_via_pbench --cmd_executing "$0" $arguments --test ${test_name}_${test} --spacing 11 --pbench_stats $to_pstats
        if [ $move_back -eq 1 ]; then
                mv /tmp/perf $move_this
        fi
        exit
fi
if [ $to_user == "ubuntu" ]; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q php-cli
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q php-xml
fi

cd $run_dir
if [[ $to_tuned_setting != "none" ]]; then
        tuned_original=`tuned-adm active | cut -d' ' -f4`
        tuned-adm profile $to_tuned_setting
fi

if [ ! -d i"./phoronix-test-suite" ]; then
  git clone -b $GIT_VERSION --single-branch --depth 1 https://github.com/phoronix-test-suite/phoronix-test-suite
fi
echo 1 | ./phoronix-test-suite/phoronix-test-suite install $test

echo 22 > /tmp/ph_opts
echo n >> /tmp/ph_opts

#
# Run phoronix test
#

if [[ -f /tmp/results_${test_name}_${test}_${to_tuned_setting}.out ]]; then
                rm /tmp/results_${test_name}_${test}_${to_tuned_setting}.out
fi

for iterations  in 1 `seq 2 1 ${to_times_to_run}`
do
  ./phoronix-test-suite/phoronix-test-suite default-run $test < /tmp/ph_opts  >> /tmp/results_${test_name}_${test}_${to_tuned_setting}.out
done
#
# Archive up the results.
#
cd /tmp
RESULTSDIR=results_${test_name}_${test}_${to_tuned_setting}$(date "+%Y.%m.%d-%H.%M.%S")
mkdir -p ${RESULTSDIR}/${test_name}_${test}_results/results_phoronix
rm results_${test_name}_${test}_${to_tuned_setting}
ln -s ${RESULTSDIR} results_${test_name}_${test}_${to_tuned_setting}

cp results_${test_name}_${test}_*.out results_${test_name}_${test}_${to_tuned_setting}/phoronix_results/results_phoronix
pushd /tmp/results_${test_name}_${test}_${to_tuned_setting}/phoronix_results/results_phoronix
$run_dir/reduce_phoronix > results_phoronix_${test}.csv
popd
tar hcf results_${test_name}_${test}_${to_tuned_setting}.tar results_${test_name}_${test}_${to_tuned_setting}
