# plutil (perl stuph)

See also https://gist.github.com/chamlin for stuph that's so small it doesn't make it here

## config_diffs.pl

run in a dir with ML config files, and it will produce ordered sets of changes/diffs with timestamps and filesets.

## stacksum.pl

summarize pstacks.  Give stacks with counts in each pstack in the movie.  Ordered by count, per pstack, descending. 

Pass it the name of a pstack movie file (not summary) on the command line.  Or, give multiples with names as nodes, and it will do them all.

Also output for flame graphs.

    for out in flame*-info.out ; do ~/git/FlameGraph/flamegraph.pl --width 1600 $out > $out.svg ; done

then

    open -a Google\ Chrome.app *.svg

use --reverse to generate reverse flamegraphs.

## pull_threads.pl

extract segfault stack traces from a log file.

-s takes a number.  this many leading space-delimited fields will be stripped.  For dealing with logs like 

mynode-01.foo.com 2017-10-20 23:46:22 Info: ...

So, just:

for log in ErrorLog\* ; do ~/git/mlutil/plutil/pull-threads.pl -s 1 $log > $log.fault ; done

## sar2csv.pl

convert chunked sar to separate csv files.  run for options.

## sar2xml.pl

convert sar to a big xml file.

suitable for load as

~/mlcp/bin/mlcp.sh import -input_file_path events.xml -input_file_type aggregates -host localhost -port 8000 -username admin -password admin -database logio-content
