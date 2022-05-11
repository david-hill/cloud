#!/bin/bash
usage="ftraceg.sh <cpu_id>"
[[ $# -ne 1 ]] && echo $usage && exit 1
debug=/sys/kernel/debug
x=$1
x=$(( 1 << $x ))
xcpu=$(printf %0.2x $x)
echo $xcpu >$debug/tracing/tracing_cpumask
echo '*' >$debug/tracing/set_ftrace_filter
echo function_graph >$debug/tracing/current_tracer
echo >$debug/tracing/trace
echo 1 >$debug/tracing/tracing_on
read -p "press ENTER key to cancel .." var
echo 0 >$debug/tracing/tracing_on
cat $debug/tracing/trace > /tmp/tracing.out$$
echo "/tmp/tracing.out$$ is created .."
