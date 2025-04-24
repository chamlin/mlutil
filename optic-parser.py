#!  /opt/homebrew/bin/python3

import re
import os
import sys
import string
import argparse
import copy

parser = argparse.ArgumentParser (
    description='Pull optic trace output from an error log'
)

parser.add_argument ('-file', dest='logfile', required=True, help='log file to scan')
#parser.add_argument ('-debug', dest='debug', default=False, help='debug output, True or False')
parser.add_argument ('-clean', dest='clean', default=False, help='strip date-time and log level, True or False')

outdir = './optic-info'

args = parser.parse_args()

print (args)

# {trace} -> {event} -> xml
results = {}
saved_times = {}

current_event = None
current_trace = None

def update_times (trace, date_time, times):
    # print (f'>  {date_time} for {repr (times)}')
    if not trace in times:
        times[trace] = {'start': date_time, 'end': date_time}
    if date_time < times[trace]['start']:
        times[trace]['start'] = date_time
    if date_time > times[trace]['end']:
        times[trace]['end'] = date_time
    # print (f'<  {date_time} for {repr (times)}')


line_number = 0
with open(args.logfile, encoding='utf-8') as logfile:
    for line in logfile:
        line_number += 1
        line = line.strip()
        date_time = line[0:23]
        m = re.search(r'Event:id=(Optic[^]]+).*trace=(\S+)', line)
        #print (line)
        if m:
            event = re.sub (' ', '-', m.group(1))
            trace = re.sub (' ', '-', m.group(2))
            if not trace in results:
                results[trace] = {event: [line]}
            elif not event in results[trace]:
                results[trace][event] = [line]
            current_trace = trace
            current_event = event
            update_times (current_trace, date_time, saved_times)
            #print (line)
            #print (f'({date_time}) {event}:{trace} - {line}')
        elif current_event and re.search (r' Info:\+', line):
            results[current_trace][current_event].append (line)
            update_times (current_trace, date_time, saved_times)
        else:
            current_trace = None
            current_event = None

for trace in results.keys ():
    for event in results[trace].keys ():
        os.makedirs (outdir + '/' + trace, 0o777, True)
        with open(outdir + '/' + trace + '/' + event, 'w') as f:
            #print (f'writing to {outdir}/{trace}/{event}')
            for line in results[trace][event]:
                if args.clean:
                    f.write (line[30:] + '\n')
                else:
                    f.write (line + '\n')

print (repr (saved_times))
