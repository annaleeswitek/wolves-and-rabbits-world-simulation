-module(rabbit_protocol_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-include_lib("../include/simulation_records.hrl").

-export([ all/0, init_per_testcase/2, end_per_testcase/2 ]).
-export([ rabbit_entity_should_have_world_state_applied/1,
          rabbit_entity_at_first_should_run_and_has_starting_position/1,
          rabbit_entity_should_report_position_when_asked/1,
          rabbit_entity_should_answer_is_it_at_specified_position/1,
          rabbit_entity_should_answer_is_it_near_specified_position/1,
          rabbit_entity_should_die_when_it_receives_eaten_event/1,
          rabbit_entity_should_aware_of_fact_that_wolf_is_around/1,
          rabbit_entity_should_broadcast_information_when_wolf_is_chasing_it/1 ]).

all() ->
    [ rabbit_entity_should_have_world_state_applied,
      rabbit_entity_at_first_should_run_and_has_starting_position,
      rabbit_entity_should_report_position_when_asked,
      rabbit_entity_should_answer_is_it_at_specified_position,
      rabbit_entity_should_answer_is_it_near_specified_position,
      rabbit_entity_should_die_when_it_receives_eaten_event,
      rabbit_entity_should_aware_of_fact_that_wolf_is_around,
      rabbit_entity_should_broadcast_information_when_wolf_is_chasing_it ].

init_per_testcase(_TestCase, Config) ->
    WorldParameters = #world_parameters{carrots = 0, rabbits = 2, wolves = 0, width = 5, height = 5},

    simulation_event_stream:start_link(),
    simulation_event_stream:attach_handler(common_test_event_handler),

    {ok, Supervisor} = simulation_rabbits_supervisor:start_link(WorldParameters),
    simulation_rabbits_supervisor:breed(WorldParameters),

    {ok, Pid} = simulation_entity_rabbit:start_link({WorldParameters, {position, 1, 2}}),

    [ {rabbit_entity_pid, Pid}, {supervisor, Supervisor}, {world_parameters, WorldParameters} | Config ].

end_per_testcase(_TestCase, Config) ->
    Pid = proplists:get_value(rabbit_entity_pid, Config),
    exit(Pid, normal),

    Supervisor = proplists:get_value(supervisor, Config),
    exit(Supervisor, normal).

rabbit_entity_should_have_world_state_applied(Config) ->
    WorldParameters = proplists:get_value(world_parameters, Config),
    Pid = proplists:get_value(rabbit_entity_pid, Config),

    {rabbit, born, EntityState} = common_test_event_handler:last_event_of(rabbit, born),

    Pid = EntityState#rabbit.pid,
    WorldParameters = EntityState#rabbit.world.

rabbit_entity_at_first_should_run_and_has_starting_position(Config) ->
    Pid = proplists:get_value(rabbit_entity_pid, Config),

    {introspection, running, State} = gen_fsm:sync_send_all_state_event(Pid, introspection),

    #position{x = 1, y = 2} = State#rabbit.position.

rabbit_entity_should_report_position_when_asked(Config) ->
    Pid = proplists:get_value(rabbit_entity_pid, Config),

    #position{x = 1, y = 2} = gen_fsm:sync_send_all_state_event(Pid, where_are_you).

rabbit_entity_should_answer_is_it_at_specified_position(Config) ->
    Pid = proplists:get_value(rabbit_entity_pid, Config),

    true = gen_fsm:sync_send_all_state_event(Pid, {are_you_at, #position{x = 1, y = 2 }}),
    false = gen_fsm:sync_send_all_state_event(Pid, {are_you_at, #position{x = 0, y = 0}}).

rabbit_entity_should_answer_is_it_near_specified_position(Config) ->
    Pid = proplists:get_value(rabbit_entity_pid, Config),

    true = gen_fsm:sync_send_all_state_event(Pid, {are_you_near, #position{x = 2, y = 3}}),
    true = gen_fsm:sync_send_all_state_event(Pid, {are_you_near, #position{x = 0, y = 0}}),
    true = gen_fsm:sync_send_all_state_event(Pid, {are_you_near, #position{x = 4, y = 4}}),

    false = gen_fsm:sync_send_all_state_event(Pid, {are_you_near, #position{x = 5, y = 5}}).

rabbit_entity_should_die_when_it_receives_eaten_event(Config) ->
    Pid = proplists:get_value(rabbit_entity_pid, Config),

    {ok, dead} = gen_fsm:sync_send_all_state_event(Pid, eaten),
    false = is_process_alive(Pid).

rabbit_entity_should_aware_of_fact_that_wolf_is_around(Config) ->
    Pid = proplists:get_value(rabbit_entity_pid, Config),

    {introspection, running, State} = gen_fsm:sync_send_all_state_event(Pid, introspection),
    ?assertEqual(false, State#rabbit.wolf_around),

    gen_fsm:send_all_state_event(Pid, {wolf_around, #position{x = 5, y = 5}}),
    {introspection, running, State} = gen_fsm:sync_send_all_state_event(Pid, introspection),
    ?assertEqual(false, State#rabbit.wolf_around),

    gen_fsm:send_all_state_event(Pid, {wolf_around, #position{x = 2, y = 3}}),
    {introspection, running, NewState} = gen_fsm:sync_send_all_state_event(Pid, introspection),
    ?assertEqual(true, NewState#rabbit.wolf_around).

rabbit_entity_should_broadcast_information_when_wolf_is_chasing_it(Config) ->
    Pid = proplists:get_value(rabbit_entity_pid, Config),

    gen_fsm:send_all_state_event(Pid, {chasing_you, #position{x = 5, y = 5}}),
    {introspection, running, State} = gen_fsm:sync_send_all_state_event(Pid, introspection),
    ?assertEqual(true, State#rabbit.wolf_around),

    {rabbit, Pid, there_is_a_wolf_around, _EntityState} = common_test_event_handler:last_event_of(rabbit, Pid, there_is_a_wolf_around).
