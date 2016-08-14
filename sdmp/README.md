# sdmp

Parse MarkLogic support dump with usual parser, then load with something like

~/mlcp/bin/mlcp.sh import -host localhost -port 8000 -username admin -password admin -input_file_path ./Support-Dump/ -mode local -output_collections xyz-slow -database sdmp

Then do the crimes, xqy-wise.
