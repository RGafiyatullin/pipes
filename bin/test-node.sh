#!/bin/bash

./rebar compile && erl -pa deps/pobox/ebin -pa ebin -eval 'pipes_test:app_start().' -sname $1
