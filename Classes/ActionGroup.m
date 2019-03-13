classdef ActionGroup
    properties
        static_rocker;
        static_shock;
        static_pushrod;
        static_lca;
        static_uca;
        static_rack;
        static_knuckle;
        action_plane;
        colors = ['r', 'g', 'b', 'k', 'm', 'c'];
        
        toelink_length;
        
        curr_rocker;
        curr_shock;
        curr_pushrod;
        curr_lca;
        curr_uca;
        curr_rack;
        curr_knuckle;
    end
   
    methods
        function self = ActionGroup(rocker, shock, pushrod, lca, uca, knuckle, rack)
            % Action group meant for sweeping the range of the suspension.
            self.static_rocker = rocker;
            self.static_shock = shock;
            self.static_pushrod = pushrod;
            self.static_lca = lca;
            self.static_uca = uca;
            self.static_knuckle = knuckle;
            self.static_rack = rack; 
            
            self.toelink_length = norm(knuckle.toe_point - rack.endpoint_location);
            
            self.curr_rocker = rocker;
            self.curr_shock = shock;
            self.curr_pushrod = pushrod;
            self.curr_lca = lca;
            self.curr_uca = uca;
            self.curr_knuckle = knuckle;
            self.curr_rack = rack; 
            self.action_plane = rocker.plane;
            
            assert(isequal(shock.outboard_point, rocker.shock_point));
            assert(isequal(knuckle.lca_point, lca.tip));
            assert(isequal(knuckle.uca_point, uca.tip));
            assert(rocker.plane.is_in_plane(shock.inboard_node.location));
        end
        
        function self = perform_sweep(self, num_steps, plot_on)
            step_size = self.static_shock.total_travel / num_steps;
            start_step = self.static_shock.total_travel / -2;
            self = self.take_shock_step(start_step);
            thetad = self.calc_knuckle_rotation();
            cambers = zeros(size(1:num_steps+1));
            toes = zeros(size(cambers));
            toes(1) = thetad;
            cambers(1) = self.curr_knuckle.calc_camber();
            if plot_on
                plot_system_3d('c', self.curr_rocker, self.curr_shock, self.curr_lca, self.curr_pushrod, self.curr_uca);
            end
            for index = 1:num_steps
                self = self.take_shock_step(step_size);
                thetad = self.calc_knuckle_rotation();
                if plot_on
                    waitforbuttonpress;
                    plot_system_3d('k', self.curr_rocker, self.curr_shock, self.curr_lca, self.curr_pushrod, self.curr_uca);
                    drawnow()
                end
                cambers(index + 1) = self.curr_knuckle.calc_camber();
                toes(index + 1) = thetad;
            end
            if plot_on
                figure
                hold on
                plot(cambers)
                plot(toes)
            end
        end
        
        function self = take_shock_step(self, step)
            self = self.calc_rocker_movement(step);
            self.curr_lca = self.calc_xca_movement(self.curr_lca, self.curr_pushrod.inboard_point, self.curr_pushrod.length);
            self.curr_knuckle.lca_point = self.curr_lca.tip;
            self.curr_pushrod.outboard_point = self.curr_lca.tip.location;
            self.curr_uca = self.calc_xca_movement(self.curr_uca, self.curr_knuckle.lca_point.location, self.curr_knuckle.control_arm_dist);
            self.curr_knuckle.uca_point = self.curr_uca.tip;
        end
        
        function self = take_rack_step(self, step)
            self.curr_rack = self.curr_rack.calc_new_endpoint(step);
            if step > 0
                direction = 1;
            else
                direction = -1;
            end
            thetad = self.calc_knuckle_rotation() * direction;
            
        end
        
        function self = calc_rocker_movement(self, step)
            prev_location = self.curr_shock.outboard_point;
            shock_radius = self.curr_shock.curr_length + step;
            shock_center = self.curr_shock.inboard_node.location;
            shock_center = self.action_plane.convert_to_planar_coor(shock_center);
            
            rocker_radius = self.curr_rocker.shock_lever;
            rocker_center = self.curr_rocker.pivot_point;
            rocker_center = self.action_plane.convert_to_planar_coor(rocker_center);
            
            [x, y] = circcirc(rocker_center(1), rocker_center(2), rocker_radius,...
                              shock_center(1), shock_center(2), shock_radius);
            p1 = [x(1); y(1)];
            p1 = self.action_plane.convert_to_global_coor(p1);
            p2 = [x(2); y(2)];
            p2 = self.action_plane.convert_to_global_coor(p2);
            new_location = self.find_closer_point(prev_location, p1, p2);
            
            new_rocker_pos = unit(new_location - self.curr_rocker.pivot_point);
            old_rocker_pos = unit(prev_location - self.curr_rocker.pivot_point);
            theta = -acosd(dot(old_rocker_pos, new_rocker_pos));

            self.curr_rocker = self.curr_rocker.rotate(theta, new_location);
            self.curr_shock = self.curr_shock.new_outboard_point(new_location);
            self.curr_pushrod.inboard_point = self.curr_rocker.control_arm_point;
        end
        
        function new_xca = calc_xca_movement(self, xca, anchor_location, anchor_dist)
            % dummy variable for when knuckle offsets are introduced
            knuckle_offset = [0;0;0];
            
            prev_location = xca.tip.location;
            
            [int1, int2] = calc_sphere_circle_int(anchor_location, anchor_dist,...
                                              xca.effective_center, xca.effective_radius, xca.action_plane);
            new_location = self.find_closer_point(prev_location, int1, int2);
            new_xca_pos = unit(new_location - xca.effective_center);
            old_xca_pos = unit(prev_location - xca.effective_center);
            theta = -acosd(dot(old_xca_pos, new_xca_pos));

            new_xca = xca.rotate(theta, new_location);

            assert(abs(norm(new_location - anchor_location) - anchor_dist) < 1e-8);
        end
        
        function point = find_closer_point(self, point_of_interest, p1, p2)
            dist1 = norm(point_of_interest - p1);
            dist2 = norm(point_of_interest - p2);
            
            if dist1 < dist2
                point = p1;
            else
                point = p2;
            end
        end
        
        function d_thetad = calc_knuckle_rotation(self)
            previous_location = self.curr_knuckle.toe_point;
            k = self.curr_knuckle;
            toe_center = k.toe_height * k.axis + k.lca_point.location;
            [p1, p2] = calc_sphere_circle_int(self.curr_rack.endpoint_location, self.toelink_length,...
                                              toe_center, k.toe_radius, k.toe_plane);
            new_location = self.find_closer_point(previous_location, p1, p2);
            prev_v = unit(prev_locaiton - toe_center);
            new_v = unit(new_location - toe_center);
            self.curr_knuckle.toe_point = new_location;
            d_thetad = acosd(dot(prev_v, new_v));
            
        end
    end
end