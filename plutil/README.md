# plutil (perl stuph)

See also https://gist.github.com/chamlin for stuph that's so small it doesn't make it here

## config_diffs.pl

run in a dir with ML config files, and it will produce ordered sets of changes/diffs with timestamps and filesets.

## stacksum.pl

summarize pstacks.  Give stacks with counts in each pstack in the movie.  Ordered by count, per pstack, descending. Also output for flame graphs.

    for out in flame*-info.out ; do ~/git/FlameGraph/flamegraph.pl --width 1600 $out > $out.svg ; done

then

    open -a Google\ Chrome.app *.svg

## stacksum2.pl

summarize pstacks.  Give stacks with counts in each pstack in the movie.  Ordered roughly by number of nodes, then by threads.  Works with multiple files.

next:  sample date-time saved

## pull_threads.pl

extract segfault stack traces from a log file.

## sar2csv.pl

convert chunked sar to separate csv files.  run for options.

## sar2xml.pl

convert sar to a big xml file.

suitable for load as

~/mlcp/bin/mlcp.sh import -input_file_path events.xml -input_file_type aggregates -host localhost -port 8000 -username admin -password admin -database logio-content
