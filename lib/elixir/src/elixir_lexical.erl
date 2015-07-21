%% Module responsible for tracking lexical information.
-module(elixir_lexical).
-export([run/3, dest/1,
  record_alias/4, record_alias/3,
  record_import/4, record_import/3,
  record_remote/3, format_error/1
]).
-include("elixir.hrl").

-define(tracker, 'Elixir.Kernel.LexicalTracker').

run(File, Dest, Callback) ->
  case elixir_compiler:get_opt(internal) of
    false ->
      {ok, Pid} = ?tracker:start_link(Dest),
      try Callback(Pid) of
        Res ->
          warn_unused_aliases(File, Pid),
          warn_unused_imports(File, Pid),
          Res
      after
        unlink(Pid),
        ?tracker:stop(Pid)
      end;
    true ->
      Callback(nil)
  end.

dest(nil) -> nil;
dest(Pid) -> ?tracker:dest(Pid).

%% RECORD

record_alias(Module, Line, Warn, Ref) ->
  if_tracker(Ref, fun(Pid) -> ?tracker:add_alias(Pid, Module, Line, Warn), ok end).

record_import(Module, Line, Warn, Ref) ->
  if_tracker(Ref, fun(Pid) -> ?tracker:add_import(Pid, Module, Line, Warn), ok end).

record_alias(Module, Function, Ref) ->
  if_tracker(Ref, fun(Pid) -> ?tracker:alias_dispatch(Pid, Module, is_compile_time(Function)), ok end).

record_import(Module, Function, Ref) ->
  if_tracker(Ref, fun(Pid) -> ?tracker:import_dispatch(Pid, Module, is_compile_time(Function)), ok end).

record_remote(Module, Function, Ref) ->
  if_tracker(Ref, fun(Pid) -> ?tracker:remote_dispatch(Pid, Module, is_compile_time(Function)), ok end).

%% HELPERS

is_compile_time(nil) -> true;
is_compile_time({_, _}) -> false.

if_tracker(nil, _Callback) -> ok;
if_tracker(Pid, Callback) when is_pid(Pid) -> Callback(Pid).

%% ERROR HANDLING

warn_unused_imports(File, Pid) ->
  [begin
    elixir_errors:form_warn([{line, L}], File, ?MODULE, {unused_import, M})
   end || {M, L} <- ?tracker:collect_unused_imports(Pid)],
  ok.

warn_unused_aliases(File, Pid) ->
  [begin
    elixir_errors:form_warn([{line, L}], File, ?MODULE, {unused_alias, M})
   end || {M, L} <- ?tracker:collect_unused_aliases(Pid)],
  ok.

format_error({unused_alias, Module}) ->
  io_lib:format("unused alias ~ts", [elixir_aliases:inspect(Module)]);
format_error({unused_import, Module}) ->
  io_lib:format("unused import ~ts", [elixir_aliases:inspect(Module)]).
