
addpath Classes

clf
d = [0.125; 0.125; 0.125]*8;
path = "./Outputs3/";
start_time = tic;
num = 0;
for sweep = 1:250

    n_pushrod_out = Node([22.79; 6; 30.72], d);

    lower_tip = [23.7; 5.75; 30.72];

    n1 = Node([9.01; 5.848-0.5; 26.63], d);
    n2 = Node([9.01; 5.576-0.5; 36.62], d);
    n3 = Node(lower_tip, [1; 0.3; 1]);
    n1.shuffle();
    n2.shuffle();
    n3.shuffle();

    lower_wishbone = AArm(n3, n2, n1, n_pushrod_out);

    upper_tip = [24.33; 12.25; 29.82];
    n11 = Node([9.48; 11.07; 26.49], d);
    n22 = Node([9.48; 11.05; 36.49], d);
    n33 = Node(upper_tip, [1; 0.3; 1]);
    n11.shuffle();
    n22.shuffle();
    n33.shuffle();
    upper_wishbone = AArm(n33, n22, n11);

    wheel = Wheel(-1, -1, [25; 8.98; 30.5], [9, 4.75, 4.75, 5.06], [0, 0, 2.92, 3.3]);

    n_outboard_toe = Node([24.38; 6.63+0.4; 32.98-0.5], d);
    n_outboard_toe.shuffle();

    knuckle = Knuckle(upper_wishbone.tip, lower_wishbone.tip, n_outboard_toe, wheel);

    n_rocker_pivot = Node([9.6; 12.5; 26], [0.25; 1; 1]);
    n_rocker_pivot.shuffle();

    p_shock_in = [9; 20.71-1.5; 27.17];
    n_shock = Node(p_shock_in, [1; 1.5; 1]);
    n_shock.shuffle();

    action_plane = Plane(n_pushrod_out.location, n_shock.location, n_rocker_pivot.location);

    p_rocker_shock = [12.37-1.5; 15.41-2; 28.07];
    n_rocker_shock = Node(p_rocker_shock, d*2);
    n_rocker_shock.shuffle();
    n_rocker_shock.location = action_plane.project_into_plane(p_rocker_shock);

    n_pushrod_in = Node([10.02; 15.15-1.5; 27.28], d*2.5);
    n_pushrod_in.shuffle();
    n_pushrod_in.location = action_plane.project_into_plane(n_pushrod_in.location);
    pushrod = Line(n_pushrod_in, n_pushrod_out);

    rocker = Rocker(n_rocker_pivot, n_rocker_shock, n_pushrod_in);

    rack_node = Node([0;6.75;30.17], [0; 1; 1]);
    % rack_node.shuffle();

    rack = Rack(rack_node, 1.25*2, 11.4);


    shock = Shock(n_shock, n_rocker_shock, action_plane);

    ag = ActionGroup(rocker, shock, pushrod, lower_wishbone, upper_wishbone, knuckle, rack, 'front');

    hold on

    plot_system_3d('k', lower_wishbone, upper_wishbone, knuckle)
    plot_system_3d('b', rocker, pushrod, shock)
    plot_system_3d('k', rack)

    tic
    for iter = 1:0
        hold on
        [static_char, dyn_char] = ag.perform_sweep(6, 0);
    end
    toc

    desired_static_char = struct('RCH', 3.5,...
                                 'spindle_length', 0,...
                                 'kingpin_angle', 1.5,...
                                 'scrub_radius', 0.1,...
                                 'anti_percentage', 0.25,...
                                 'FVSA', 69,...
                                 'SVSA', 110,...
                                 'mechanical_trail', 1,...
                                 'interference', 0);

    static_char_weights = struct('RCH', 80,...
                                 'spindle_length', 2,...
                                 'kingpin_angle', 2,...
                                 'scrub_radius', 3,...
                                 'anti_percentage', 6,...
                                 'FVSA', 5,...
                                 'SVSA', 5,...
                                 'mechanical_trail', 5,...
                                 'interference', 100);

    desired_dyn_char = struct('bump_steer', 0,...
                              'min_wheel_travel', 1.98,...
                              'wheel_travel', 2.1,...
                              'scrub', 0,...
                              'max_steer_angle', 30);

    dyn_char_weights = struct('bump_steer', 5,...
                              'min_wheel_travel', 100,...
                              'wheel_travel', 1,...
                              'scrub', 3,...
                              'max_steer_angle', 50);


    % fitness = calc_fitness(static_char, desired_static_char, static_char_weights)
    try
        o = Optimizer(ag, 10, desired_static_char, static_char_weights, desired_dyn_char, dyn_char_weights);
    catch
        continue;
    end
    % 50000 simulations = 72 seconds as of 3/9/19 (Shock Sweep only)
    % 5000 Simulations = 120 seconds as of 3/19/19 (Shock and Rack Sweep)
    % 5000 Simulations = 212 seconds as of 3/23/19 (shock, and rack sweep, 6x6, line
    % interference detection)
    % 5000 Simulations = 367 seconds as of 3/31/19 (shock, rack sweep, 6x6,
    % line and circle interference detection, IC, RC, wheel travel, some object optimization,
    % printing)
    % 5000 Simulations = 261 seconds as of 3/31/19 (shock, rack sweep, 6x6,
    % line and circle interference detection, IC, RC, wheel travel, some object optimization,
    % less printing)
    % 5000 Simulations = 234 seconds as of 4/16/19 (shock, rack sweep, 6x6,
    % line and circle interference detection, IC, RC, wheel travel, better object
    % optimization)
    if min(o.fitnesses) < 50
        filename = path + "front-" + num2str(round(min(o.fitnesses))) + "-";
        tag = 0;
        while isfile(filename + num2str(tag) + ".mat")
            tag = tag + 1;
        end
        filename = filename + num2str(tag);
        save(filename)
        num = num+1;
    end
end

toc(start_time)
disp(num)

